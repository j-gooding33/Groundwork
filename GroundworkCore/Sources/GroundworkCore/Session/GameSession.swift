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
    /// For an input used faster than it arrives: seconds until the building's
    /// stock runs out at the current rates. Nil when supply keeps up.
    public var runsOutInSeconds: Int?

    /// Seconds until it runs out, if that is within `limit` seconds.
    public func runsOut(within limit: Int) -> Int? {
        runsOutInSeconds.flatMap { $0 <= limit ? $0 : nil }
    }

    /// Every item a building has handled, with its rates at `tick`.
    public static func all(for building: Building, tick: UInt64, rules: GameRules) -> [ItemRate] {
        building.rates.trackedItems.map { item in
            let used = building.rates.perMinute(.used, item, tick: tick, rules: rules)
            let received = building.rates.perMinute(.received, item, tick: tick, rules: rules)
            let falling = used - received
            let runsOut = falling > 0 ? building.input.count(of: item) * 60 / falling : nil
            return ItemRate(item: item, made: building.rates.perMinute(.made, item, tick: tick, rules: rules),
                            used: used, received: received, runsOutInSeconds: runsOut)
        }
    }
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

    /// Starts a level: its map, preplaced buildings, unlocks, belt stock and tutorial.
    public convenience init(content: ContentDatabase, level id: LevelID, seed: UInt64 = 1) throws {
        guard let level = content.level(id) else {
            throw ContentError.invalid(["Unknown level '\(id)'"])
        }
        self.init(content: content, map: try content.map(for: level), seed: seed)
        LevelRunner.start(level, world: &world, content: content, events: &events)
        afterEvents(since: 0, byPlayer: false, succeeded: true)
    }

    private init(content: ContentDatabase, world: World) {
        self.content = content
        self.world = world
        self.world.index = WorldIndex(world: world, content: content)
    }

    // MARK: Time

    /// Runs whole ticks. Fast-forward calls this with more ticks per frame.
    /// While a tutorial step asks for a pause, time waits for the player.
    public func advance(ticks: Int) {
        precondition(ticks >= 0, "Cannot advance by a negative number of ticks")
        for _ in 0..<ticks {
            if isPausedByTutorial { return }
            let mark = events.count
            Simulation.step(&world, content: content, events: &events)
            afterEvents(since: mark, byPlayer: false, succeeded: true)
        }
    }

    public var isPausedByTutorial: Bool { tutorialStep?.pauseSim == true }

    /// Lets the level and the fun-test log react to new events.
    private func afterEvents(since mark: Int, byPlayer: Bool, succeeded: Bool) {
        if world.level != nil {
            LevelRunner.update(&world, content: content, newEvents: events[mark...], events: &events)
        }
        world.funTest.record(events[mark...], tick: world.tick, byPlayer: byPlayer, succeeded: succeeded)
    }

    /// Runs a command, then lets the level react to what it did.
    private func command(_ body: () -> CommandResult) -> CommandResult {
        let mark = events.count
        let result = body()
        afterEvents(since: mark, byPlayer: true, succeeded: result.isOK)
        return result
    }

    // MARK: Commands

    @discardableResult
    public func place(_ type: BuildingTypeID, at origin: GridPoint, facing: Direction = .south) -> CommandResult {
        command { placeNow(type, at: origin, facing: facing) }
    }

    private func placeNow(_ type: BuildingTypeID, at origin: GridPoint, facing: Direction) -> CommandResult {
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
        command { removeNow(id) }
    }

    private func removeNow(_ id: EntityID) -> CommandResult {
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
        command { layBeltNow(from: from, to: to) }
    }

    private func layBeltNow(from: GridPoint, to: GridPoint) -> CommandResult {
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
        command { removeBeltNow(at: point) }
    }

    private func removeBeltNow(at point: GridPoint) -> CommandResult {
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
        command { pickUpNow(from: id, item: item, count: count) }
    }

    private func pickUpNow(from id: EntityID, item: ItemID?, count: Int) -> CommandResult {
        switch Commands.pickUp(from: id, item: item, count: count, world: &world, content: content) {
        case .success: return .ok
        case let .failure(error): return .rejected(error)
        }
    }

    /// Drops as much of what the hands hold as the building will take.
    @discardableResult
    public func drop(into id: EntityID) -> CommandResult {
        command { dropNow(into: id) }
    }

    private func dropNow(into id: EntityID) -> CommandResult {
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
        command { undoNow() }
    }

    private func undoNow() -> CommandResult {
        guard let entry = undoStack.popLast() else { return .rejected(.nothingToUndo) }
        switch entry {
        case let .placed(id):
            guard case let .success(building) = Commands.remove(id, world: &world, content: content) else {
                return undoNow()
            }
            events.append(.buildingRemoved(id, building.type))
        case let .removed(building):
            if case let .failure(error) = Commands.restore(building, world: &world, content: content) {
                return .rejected(error)
            }
            events.append(.buildingPlaced(building.id, building.type))
        case let .beltLaid(points):
            let removed = Commands.removeBelts(at: points, world: &world, content: content)
            if removed.isEmpty { return undoNow() }
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

    // MARK: Level

    public var level: LevelDef? { world.level.flatMap { content.level($0.level) } }

    /// The guided step showing now, or nil when there is none or the tutorial is done.
    public var tutorialStep: TutorialStep? { LevelRunner.currentStep(world: world, content: content) }

    public var goal: GoalProgress? { LevelRunner.goalProgress(world: world, content: content) }

    public var isGoalReached: Bool { world.level?.goalReached ?? false }

    /// Fun-test numbers for the debug overlay.
    public var funTest: FunTestLog { world.funTest }

    // MARK: Queries

    /// Runs Trace. Trace itself is pure; the session only notes that the player
    /// asked about a building, which some tutorial steps wait for.
    @discardableResult
    public func trace(_ target: TraceTarget) -> TraceResult {
        let result = Trace.run(target, world: world, content: content)
        if case let .building(id) = target, let type = world.building(id)?.type {
            LevelRunner.note(TutorialCondition.traced(type).key, world: &world, content: content, events: &events)
        }
        return result
    }

    /// The app reports UI actions the tutorial may wait for ("panned", "zoomed").
    public func noteUI(_ name: String) {
        LevelRunner.note(TutorialCondition.ui(name).key, world: &world, content: content, events: &events)
    }

    /// Ends the tutorial now, handing over everything its remaining steps would unlock.
    public func skipTutorial() {
        LevelRunner.skipTutorial(world: &world, content: content, events: &events)
    }

    /// Made, used and received per minute for every item the building has handled.
    public func rates(of id: EntityID) -> [ItemRate] {
        guard let building = world.building(id) else { return [] }
        return ItemRate.all(for: building, tick: world.tick, rules: content.rules)
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
