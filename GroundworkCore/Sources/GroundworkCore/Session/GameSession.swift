import Foundation

public enum CommandResult: Equatable, Sendable {
    case ok
    case rejected(CommandError)

    public var isOK: Bool { self == .ok }
}

/// One item's rates at a building, per minute.
public struct ItemRate: Equatable, Sendable {
    public var item: ItemID
    public var made: Int
    public var used: Int
    public var received: Int
}

/// The one entry point a renderer or UI uses. It owns the world and the
/// content, applies player commands, advances the simulation, and saves and
/// loads. Nothing else in GroundworkCore needs to be called from the app.
public final class GameSession {
    public let content: ContentDatabase
    public private(set) var world: World
    private var events: [GameEvent] = []
    private var undoStack: [UndoEntry] = []

    private enum UndoEntry {
        case placed(EntityID)
        case removed(Building)
        case beltLaid([GridPoint])
        case beltRemoved([BeltTile])
    }

    public init(content: ContentDatabase, map: TileMap, seed: UInt64) {
        self.content = content
        world = World(map: map, seed: seed)
        world.index = WorldIndex(world: world, content: content)
    }

    private init(content: ContentDatabase, world: World) {
        self.content = content
        self.world = world
        self.world.index = WorldIndex(world: world, content: content)
    }

    // MARK: Time

    /// Runs whole ticks. Fast-forward calls this with more ticks per frame.
    public func advance(ticks: Int) {
        precondition(ticks >= 0, "Cannot advance by a negative number of ticks")
        for _ in 0..<ticks {
            Simulation.step(&world, content: content, events: &events)
        }
    }

    // MARK: Commands

    @discardableResult
    public func place(_ type: BuildingTypeID, at origin: GridPoint, facing: Direction = .south) -> CommandResult {
        switch Commands.place(type, at: origin, facing: facing, world: &world, content: content) {
        case let .success(id):
            undoStack.append(.placed(id))
            events.append(.buildingPlaced(id, type))
            return .ok
        case let .failure(error):
            return .rejected(error)
        }
    }

    /// Removes a building. Anything it was holding is lost (undo brings it back).
    @discardableResult
    public func remove(_ id: EntityID) -> CommandResult {
        switch Commands.remove(id, world: &world, content: content) {
        case let .success(building):
            undoStack.append(.removed(building))
            events.append(.buildingRemoved(id, building.type))
            return .ok
        case let .failure(error):
            return .rejected(error)
        }
    }

    /// Where a belt dragged between two tiles would go, for the ghost preview.
    public func previewBelt(from: GridPoint, to: GridPoint) -> [GridPoint]? {
        try? BeltRouting.plan(from: from, to: to, world: world, content: content).get().points
    }

    /// Lays a belt. Starting on a building takes items from it; ending on a
    /// building or belt feeds into it. The route avoids obstacles by itself.
    @discardableResult
    public func layBelt(from: GridPoint, to: GridPoint) -> CommandResult {
        switch Commands.layBelt(from: from, to: to, world: &world, content: content) {
        case let .success(points):
            undoStack.append(.beltLaid(points))
            events.append(.beltLaid(points))
            return .ok
        case let .failure(error):
            return .rejected(error)
        }
    }

    @discardableResult
    public func removeBelt(at point: GridPoint) -> CommandResult {
        let removed = Commands.removeBelts(at: [point], world: &world, content: content)
        guard !removed.isEmpty else { return .rejected(.unknown("There is no belt there")) }
        undoStack.append(.beltRemoved(removed))
        events.append(.beltRemoved(removed.map(\.point)))
        return .ok
    }

    /// Picks items up into the player's hands. With no item given, takes what
    /// the hands already hold, or else the first thing available.
    @discardableResult
    public func pickUp(from id: EntityID, item: ItemID? = nil, count: Int = .max) -> CommandResult {
        switch Commands.pickUp(from: id, item: item, count: count, world: &world, content: content) {
        case .success: return .ok
        case let .failure(error): return .rejected(error)
        }
    }

    /// Drops as much of what the hands hold as the building will take.
    @discardableResult
    public func drop(into id: EntityID) -> CommandResult {
        switch Commands.drop(into: id, world: &world, content: content) {
        case let .success(stack):
            events.append(.itemDelivered(id, stack.item, via: .hand))
            return .ok
        case let .failure(error):
            return .rejected(error)
        }
    }

    /// Undoes the last place, remove or belt action. Hand-carrying is not undoable.
    @discardableResult
    public func undo() -> CommandResult {
        guard let entry = undoStack.popLast() else { return .rejected(.nothingToUndo) }
        switch entry {
        case let .placed(id):
            guard case let .success(building) = Commands.remove(id, world: &world, content: content) else {
                return undo()
            }
            events.append(.buildingRemoved(id, building.type))
        case let .removed(building):
            if case let .failure(error) = Commands.restore(building, world: &world, content: content) {
                return .rejected(error)
            }
            events.append(.buildingPlaced(building.id, building.type))
        case let .beltLaid(points):
            let removed = Commands.removeBelts(at: points, world: &world, content: content)
            if removed.isEmpty { return undo() }
            events.append(.beltRemoved(removed.map(\.point)))
        case let .beltRemoved(tiles):
            if case let .failure(error) = Commands.restoreBelts(tiles, world: &world, content: content) {
                return .rejected(error)
            }
            events.append(.beltLaid(tiles.map(\.point)))
        }
        return .ok
    }

    public var canUndo: Bool { !undoStack.isEmpty }

    // MARK: Queries

    public func trace(_ target: TraceTarget) -> TraceResult {
        Trace.run(target, world: world, content: content)
    }

    /// Made, used and received per minute for every item the building has handled.
    public func rates(of id: EntityID) -> [ItemRate] {
        guard let building = world.building(id) else { return [] }
        let rules = content.rules
        return building.rates.trackedItems.map { item in
            ItemRate(item: item,
                     made: building.rates.perMinute(.made, item, tick: world.tick, rules: rules),
                     used: building.rates.perMinute(.used, item, tick: world.tick, rules: rules),
                     received: building.rates.perMinute(.received, item, tick: world.tick, rules: rules))
        }
    }

    /// Events since the last call, oldest first.
    public func drainEvents() -> [GameEvent] {
        defer { events.removeAll() }
        return events
    }

    // MARK: Saving

    /// The world as JSON. Keys are sorted, so the same world always gives the same bytes.
    /// The undo history is not saved.
    public func save() throws -> Data {
        try Self.encoder.encode(world)
    }

    public static func load(_ data: Data, content: ContentDatabase) throws -> GameSession {
        GameSession(content: content, world: try JSONDecoder().decode(World.self, from: data))
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    // MARK: Setup hooks for levels and tests

    /// Gives a building items directly, as level data does for the kiln's starting fuel.
    public func stock(_ id: EntityID, with item: ItemID, count: Int) {
        guard let i = world.buildingIndex(id) else { return }
        world.buildings[i].input.add(item, count)
    }

    public func setBeltsAvailable(_ count: Int?) { world.beltsAvailable = count }
    public func setUnlocked(_ types: [BuildingTypeID]?) { world.unlocked = types }
    public func setHousingPlots(_ plots: [GridPoint]) { world.housingPlots = plots }
}
