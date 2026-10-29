/// Why a command was refused, with a sentence short enough for a toast.
public enum CommandError: Error, Equatable, Sendable {
    case unknown(String)
    case notUnlocked(String)
    case blocked(String)
    case noRoom(String)
    case noRoute(String)
    case needsSource(String)
    case builtByYard(String)
    case outOfBelts(String)
    case hands(String)
    case nothingToUndo

    public var message: String {
        switch self {
        case let .unknown(m), let .notUnlocked(m), let .blocked(m), let .noRoom(m), let .noRoute(m),
             let .needsSource(m), let .builtByYard(m), let .outOfBelts(m), let .hands(m):
            return m
        case .nothingToUndo:
            return "Nothing to undo"
        }
    }
}

/// Player actions that change the world. Each returns enough to undo itself.
enum Commands {
    static func place(_ type: BuildingTypeID, at origin: GridPoint, facing: Direction,
                      world: inout World, content: ContentDatabase) -> Result<EntityID, CommandError> {
        guard let def = content.building(type) else { return .failure(.unknown("Unknown building '\(type)'")) }
        if let unlocked = world.unlocked, !unlocked.contains(type) {
            return .failure(.notUnlocked("The \(def.name) is not unlocked yet"))
        }
        if let yard = content.buildings.first(where: { $0.builds == type }) {
            return .failure(.builtByYard("\(def.name)s are built by the \(yard.name)"))
        }
        if let problem = placementProblem(def, at: origin, world: world, content: content) {
            return .failure(problem)
        }
        let id = insertBuilding(type, at: origin, facing: facing, world: &world, content: content)
        return .success(id)
    }

    static func placementProblem(_ def: BuildingDef, at origin: GridPoint, world: World,
                                 content: ContentDatabase) -> CommandError? {
        for dy in 0..<def.height {
            for dx in 0..<def.width {
                let point = GridPoint(origin.x + dx, origin.y + dy)
                guard let terrain = world.map.terrain(at: point) else {
                    return .blocked("Too close to the edge of the map")
                }
                if terrain.isWater { return .blocked("Cannot build on water") }
                if world.index.occupant(at: point) != nil { return .blocked("Something is already here") }
            }
        }
        if def.placeOn == .source {
            let sources = def.recipes.compactMap { content.recipe($0)?.source }
            guard let sourceID = sources.first, let source = content.source(sourceID) else {
                return .needsSource("Nothing to gather")
            }
            guard let deposit = world.map.deposit(at: origin), sources.contains(deposit.source) else {
                return .needsSource("The \(def.name) needs a \(source.name.lowercased())")
            }
            if let remaining = deposit.remaining, remaining <= 0 {
                return .needsSource("This \(source.name.lowercased()) is used up")
            }
        }
        return nil
    }

    /// Adds a building without player checks. Ids only grow, so appending keeps them sorted.
    @discardableResult
    static func insertBuilding(_ type: BuildingTypeID, at origin: GridPoint, facing: Direction,
                               world: inout World, content: ContentDatabase) -> EntityID {
        let id = world.nextEntityID
        world.nextEntityID += 1
        world.buildings.append(Building(id: id, type: type, origin: origin, facing: facing,
                                        tick: world.tick, rules: content.rules))
        world.index = WorldIndex(world: world, content: content)
        return id
    }

    static func remove(_ id: EntityID, world: inout World, content: ContentDatabase) -> Result<Building, CommandError> {
        guard let i = world.buildingIndex(id) else { return .failure(.unknown("That building is gone")) }
        let removed = world.buildings.remove(at: i)
        world.index = WorldIndex(world: world, content: content)
        return .success(removed)
    }

    /// Puts a removed building back exactly as it was, if its tiles are still free.
    static func restore(_ building: Building, world: inout World, content: ContentDatabase) -> Result<Void, CommandError> {
        guard let def = content.building(building.type) else { return .failure(.unknown("Unknown building")) }
        for point in building.footprint(def) where !world.isFree(point) {
            return .failure(.blocked("Something has been built where the \(def.name) was"))
        }
        let position = world.buildings.firstIndex { $0.id > building.id } ?? world.buildings.endIndex
        world.buildings.insert(building, at: position)
        world.index = WorldIndex(world: world, content: content)
        return .success(())
    }

    static func layBelt(from: GridPoint, to: GridPoint, world: inout World,
                        content: ContentDatabase) -> Result<[GridPoint], CommandError> {
        switch BeltRouting.plan(from: from, to: to, world: world, content: content) {
        case let .failure(error):
            return .failure(error)
        case let .success(plan):
            if let available = world.beltsAvailable, plan.points.count > available {
                return .failure(.outOfBelts("This belt needs \(plan.points.count) tiles and you have \(available)"))
            }
            for (k, point) in plan.points.enumerated() {
                world.belts.append(BeltTile(point: point, direction: plan.directions[k],
                                            slots: content.rules.beltSlotsPerTile,
                                            pullsFrom: k == 0 ? plan.pullsFrom : nil))
            }
            if let available = world.beltsAvailable { world.beltsAvailable = available - plan.points.count }
            BeltSystem.reorder(&world, content: content)
            return .success(plan.points)
        }
    }

    /// Removes belt tiles and returns them (items on them are lost). Refunds belt stock.
    static func removeBelts(at points: [GridPoint], world: inout World, content: ContentDatabase) -> [BeltTile] {
        let wanted = Set(points)
        let removed = world.belts.filter { wanted.contains($0.point) }.sorted { $0.point < $1.point }
        guard !removed.isEmpty else { return [] }
        world.belts.removeAll { wanted.contains($0.point) }
        if let available = world.beltsAvailable { world.beltsAvailable = available + removed.count }
        BeltSystem.reorder(&world, content: content)
        return removed
    }

    static func restoreBelts(_ tiles: [BeltTile], world: inout World, content: ContentDatabase) -> Result<Void, CommandError> {
        for tile in tiles where !world.isFree(tile.point) {
            return .failure(.blocked("Something has been built where the belt was"))
        }
        if let available = world.beltsAvailable {
            guard available >= tiles.count else { return .failure(.outOfBelts("Not enough belt left to put it back")) }
            world.beltsAvailable = available - tiles.count
        }
        world.belts += tiles
        BeltSystem.reorder(&world, content: content)
        return .success(())
    }

    // MARK: Hand carry

    static func pickUp(from id: EntityID, item wanted: ItemID?, count: Int, world: inout World,
                       content: ContentDatabase) -> Result<ItemStack, CommandError> {
        guard let i = world.buildingIndex(id), let def = content.building(world.buildings[i].type) else {
            return .failure(.unknown("That building is gone"))
        }
        guard let inventory = Production.takeable(world.buildings[i], def: def), !inventory.isEmpty else {
            return .failure(.hands("Nothing to pick up from the \(def.name)"))
        }
        let held = world.hand
        guard let item = wanted ?? held?.item ?? inventory.stacks.first?.item else {
            return .failure(.hands("Nothing to pick up"))
        }
        if let held, held.item != item {
            return .failure(.hands("Your hands are full of \(content.plural(held.item))"))
        }
        let space = content.rules.handCapacity - (held?.count ?? 0)
        guard space > 0 else { return .failure(.hands("Your hands are full")) }
        let taken = Production.take(item, min(max(count, 0), space), from: i, world: &world, def: def)
        guard taken > 0 else { return .failure(.hands("The \(def.name) has no \(content.plural(item))")) }
        world.hand = ItemStack(item: item, count: (held?.count ?? 0) + taken)
        return .success(ItemStack(item: item, count: taken))
    }

    static func drop(into id: EntityID, world: inout World, content: ContentDatabase) -> Result<ItemStack, CommandError> {
        guard let held = world.hand else { return .failure(.hands("Your hands are empty")) }
        guard let i = world.buildingIndex(id), let def = content.building(world.buildings[i].type) else {
            return .failure(.unknown("That building is gone"))
        }
        let room = Production.room(for: held.item, in: world.buildings[i], def: def, content: content)
        guard room > 0 else {
            return .failure(.hands("The \(def.name) does not take \(content.plural(held.item)) right now"))
        }
        let dropped = min(room, held.count)
        Production.deliver(held.item, dropped, to: i, world: &world, content: content)
        world.hand = held.count > dropped ? ItemStack(item: held.item, count: held.count - dropped) : nil
        return .success(ItemStack(item: held.item, count: dropped))
    }
}
