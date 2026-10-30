/// Gatherers and processors: start a craft when inputs and output room allow,
/// finish it after the recipe's duration.
enum Production {
    static func step(_ world: inout World, content: ContentDatabase, events: inout [GameEvent]) {
        for i in world.buildings.indices {
            let type = world.buildings[i].type
            guard let def = content.building(type) else { continue }
            switch def.kind {
            case .gatherer, .processor:
                guard let recipe = def.recipes.first.flatMap(content.recipe) else { continue }
                feedSoil(&world, i, def: def, rules: content.rules)
                craft(&world, i, recipe: recipe, def: def, content: content, events: &events)
            case .home:
                if world.buildings[i].buildRemaining > 0 {
                    world.buildings[i].buildRemaining -= 1
                    if world.buildings[i].buildRemaining == 0 {
                        events.append(.homeCompleted(world.buildings[i].id))
                    }
                }
            case .storage, .construction, .yard:
                break
            }
        }
    }

    private static func craft(_ world: inout World, _ i: Int, recipe: RecipeDef, def: BuildingDef,
                              content: ContentDatabase, events: inout [GameEvent]) {
        let tick = world.tick
        let rules = content.rules

        // Ticks of work count from the tick a craft starts. A craft that starts
        // on the tick the previous one finished gets no work that tick, so a
        // fed machine makes exactly one batch per recipe duration.
        var justFinished = false
        if world.buildings[i].crafting {
            world.buildings[i].progress += 1
            guard world.buildings[i].progress >= duration(recipe, world.buildings[i], def, content.rules) else { return }
            finish(&world, i, recipe: recipe, content: content, events: &events)
            justFinished = true
        }

        if let reason = blockReason(world.buildings[i], recipe: recipe, def: def, world: world, content: content) {
            if world.buildings[i].waitReason != reason {
                world.buildings[i].waitReason = reason
                world.buildings[i].waitingTicks = 0
            }
            world.buildings[i].waitingTicks += 1
            if case let .sourceDepleted(source) = reason, world.buildings[i].waitingTicks == 1 {
                events.append(.sourceDepleted(world.buildings[i].origin, source))
            }
            return
        }

        if let source = recipe.source, content.source(source)?.everywhere != true {
            _ = world.map.take(gatherAmount(recipe), at: world.buildings[i].origin)
        }
        if let use = def.soilUse {
            world.buildings[i].soil = max(0, (world.buildings[i].soil ?? rules.soilMax) - use)
        }
        for input in recipe.inputs {
            world.buildings[i].input.remove(input.item, input.count)
            world.buildings[i].rates.record(.used, input.item, input.count, tick: tick, rules: rules)
        }
        world.buildings[i].waitReason = nil
        world.buildings[i].waitingTicks = 0
        world.buildings[i].crafting = true
        world.buildings[i].progress = justFinished ? 0 : 1
        if world.buildings[i].progress >= duration(recipe, world.buildings[i], def, rules) {
            // A one-tick recipe started fresh finishes on the tick it starts.
            finish(&world, i, recipe: recipe, content: content, events: &events)
        }
    }

    /// A recipe's time, doubled on tired soil.
    static func duration(_ recipe: RecipeDef, _ building: Building, _ def: BuildingDef, _ rules: GameRules) -> Int {
        isSoilTired(building, def, rules) ? recipe.durationTicks * 2 : recipe.durationTicks
    }

    static func isSoilTired(_ building: Building, _ def: BuildingDef, _ rules: GameRules) -> Bool {
        def.soilUse != nil && (building.soil ?? rules.soilMax) < rules.soilTired
    }

    /// Works compost into the soil, one at a time, while there is room for it.
    private static func feedSoil(_ world: inout World, _ i: Int, def: BuildingDef, rules: GameRules) {
        guard let feed = def.soilFeed, let per = def.soilPerFeed,
              world.buildings[i].input.count(of: feed) > 0 else { return }
        let soil = world.buildings[i].soil ?? rules.soilMax
        guard soil + per <= rules.soilMax else { return }
        world.buildings[i].input.remove(feed, 1)
        world.buildings[i].soil = soil + per
    }

    private static func finish(_ world: inout World, _ i: Int, recipe: RecipeDef, content: ContentDatabase,
                               events: inout [GameEvent]) {
        world.buildings[i].crafting = false
        world.buildings[i].progress = 0
        for out in recipe.outputs {
            world.buildings[i].output.add(out.item, out.count)
            world.buildings[i].rates.record(.made, out.item, out.count, tick: world.tick, rules: content.rules)
            events.append(.itemProduced(world.buildings[i].id, out.item, count: out.count))
        }
    }

    /// Units a gathering recipe takes from its deposit per craft: one per item it makes.
    static func gatherAmount(_ recipe: RecipeDef) -> Int {
        recipe.outputs.reduce(0) { $0 + $1.count }
    }

    /// Why the building cannot start its recipe now, or nil if it can.
    static func blockReason(_ building: Building, recipe: RecipeDef, def: BuildingDef, world: World,
                            content: ContentDatabase) -> BlockReason? {
        let produced = recipe.outputs.reduce(0) { $0 + $1.count }
        if building.output.total + produced > def.outputCapacity { return .outputFull }
        if let source = recipe.source, content.source(source)?.everywhere != true {
            guard let deposit = world.map.deposit(at: building.origin), deposit.source == source else { return .noSource }
            if let remaining = deposit.remaining, remaining < gatherAmount(recipe) { return .sourceDepleted(source) }
        }
        for input in recipe.inputs where building.input.count(of: input.item) < input.count {
            return input.role == .fuel ? .missingFuel(input.item) : .missingInput(input.item)
        }
        if recipe.power > 0, !world.isPowered(building.id) { return .noPower }
        if def.waterUse != nil, !world.hasWater(building.id) { return .noWater }
        return nil
    }

    // MARK: What a building takes and gives

    /// How many more of an item the building will take in.
    static func room(for item: ItemID, in building: Building, def: BuildingDef, content: ContentDatabase) -> Int {
        guard building.isBuilt else { return 0 }
        switch def.kind {
        case _ where def.soilFeed == item:
            return max(0, def.inputCapacity - building.input.count(of: item))
        case .processor:
            let needed = def.recipes.compactMap(content.recipe).contains { $0.inputs.contains { $0.item == item } }
            return needed ? max(0, def.inputCapacity - building.input.count(of: item)) : 0
        case .storage:
            guard def.accepts.isEmpty || def.accepts.contains(item) else { return 0 }
            return max(0, def.inputCapacity - building.input.total)
        case .construction:
            return def.accepts.contains(item) ? remainingCapacity(of: building, def: def, rules: content.rules) : 0
        case .yard:
            return def.accepts.contains(item) ? max(0, def.inputCapacity - building.input.count(of: item)) : 0
        case .gatherer, .home:
            return 0
        }
    }

    static func remainingCapacity(of building: Building, def: BuildingDef, rules: GameRules) -> Int {
        max(0, def.inputCapacity - building.input.total)
    }

    /// The inventory belts and hands take from, if any.
    static func takeable(_ building: Building, def: BuildingDef) -> Inventory? {
        switch def.kind {
        case .gatherer, .processor: return building.output
        case .storage: return building.input
        case .construction, .yard, .home: return nil
        }
    }

    /// Removes up to `count` of an item from the takeable inventory. Returns how many were taken.
    static func take(_ item: ItemID, _ count: Int, from i: Int, world: inout World, def: BuildingDef) -> Int {
        switch def.kind {
        case .gatherer, .processor: return world.buildings[i].output.remove(item, count)
        case .storage: return world.buildings[i].input.remove(item, count)
        case .construction, .yard, .home: return 0
        }
    }

    /// Puts items into a building's input and counts them as received.
    static func deliver(_ item: ItemID, _ count: Int, to i: Int, world: inout World, content: ContentDatabase) {
        world.buildings[i].input.add(item, count)
        world.buildings[i].rates.record(.received, item, count, tick: world.tick, rules: content.rules)
    }
}

extension Building {
    /// A field whose soil is worn out grows at half speed until it gets compost.
    public func hasTiredSoil(_ def: BuildingDef, rules: GameRules) -> Bool {
        Production.isSoilTired(self, def, rules)
    }
}
