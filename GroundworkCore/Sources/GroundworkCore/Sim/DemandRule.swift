/// The prototype's one automation rule: a Builder's Yard starts the next home
/// by itself once its brick and plank supply is steady.
///
/// Steady means: the yard has existed for a full rate window, it received at
/// least one home's worth of each material during that window (or is full of
/// it, so supply is backing up), and it holds a home's worth now.
enum DemandRule {
    static func step(_ world: inout World, content: ContentDatabase, events: inout [GameEvent]) {
        let rules = content.rules
        for i in world.buildings.indices {
            guard let def = content.building(world.buildings[i].type), def.kind == .yard,
                  let homeType = def.builds, let homeDef = content.building(homeType) else { continue }

            if let job = world.buildings[i].job {
                if let home = world.building(job), !home.isBuilt { continue }
                world.buildings[i].job = nil
            }
            guard isSupplySteady(world.buildings[i], cost: homeDef.cost, capacity: def.inputCapacity,
                                 tick: world.tick, rules: rules),
                  let origin = siteForHome(homeDef, near: world.buildings[i], yardDef: def,
                                           world: world, content: content) else { continue }

            for stack in homeDef.cost {
                world.buildings[i].input.remove(stack.item, stack.count)
                world.buildings[i].rates.record(.used, stack.item, stack.count, tick: world.tick, rules: rules)
            }
            let yardID = world.buildings[i].id
            let homeID = Commands.insertBuilding(homeType, at: origin, facing: .south, world: &world, content: content)
            if let h = world.buildingIndex(homeID) {
                world.buildings[h].buildRemaining = def.buildTicks ?? 1
                world.buildings[h].status = .constructing
            }
            if let y = world.buildingIndex(yardID) { world.buildings[y].job = homeID }
            events.append(.buildingPlaced(homeID, homeType))
            events.append(.homeStarted(homeID, by: yardID))
        }
    }

    static func isSupplySteady(_ yard: Building, cost: [ItemStack], capacity: Int, tick: UInt64,
                               rules: GameRules) -> Bool {
        guard !cost.isEmpty, tick >= yard.placedAtTick + UInt64(rules.rateWindowTicks) else { return false }
        return cost.allSatisfy { stack in
            let held = yard.input.count(of: stack.item)
            // A full yard receives nothing, which must not read as a dry supply.
            return held >= stack.count
                && (held >= capacity || yard.rates.countInWindow(.received, stack.item, tick: tick, rules: rules) >= stack.count)
        }
    }

    /// The first free housing plot, or else the nearest free spot to the yard,
    /// scanning outward ring by ring in row-major order. Avoids natural sources
    /// and keeps a one-tile gap from other buildings so belts can pass.
    static func siteForHome(_ homeDef: BuildingDef, near yard: Building, yardDef: BuildingDef,
                            world: World, content: ContentDatabase) -> GridPoint? {
        func fits(_ origin: GridPoint) -> Bool {
            for dy in 0..<homeDef.height {
                for dx in 0..<homeDef.width {
                    let point = GridPoint(origin.x + dx, origin.y + dy)
                    if !world.isFree(point) || world.map.deposit(at: point) != nil { return false }
                }
            }
            for dy in -1...homeDef.height {
                for dx in -1...homeDef.width where world.building(at: GridPoint(origin.x + dx, origin.y + dy)) != nil {
                    return false
                }
            }
            return true
        }
        if !world.housingPlots.isEmpty {
            return world.housingPlots.first(where: fits)
        }
        let maxRadius = max(world.map.width, world.map.height)
        for radius in 1...maxRadius {
            var ring: [GridPoint] = []
            for y in (yard.origin.y - radius)...(yard.origin.y + yardDef.height - 1 + radius) {
                for x in (yard.origin.x - radius)...(yard.origin.x + yardDef.width - 1 + radius) {
                    let onEdge = y == yard.origin.y - radius || y == yard.origin.y + yardDef.height - 1 + radius
                        || x == yard.origin.x - radius || x == yard.origin.x + yardDef.width - 1 + radius
                    if onEdge { ring.append(GridPoint(x, y)) }
                }
            }
            if let spot = ring.sorted().first(where: fits) { return spot }
        }
        return nil
    }
}
