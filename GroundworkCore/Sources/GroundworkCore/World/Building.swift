public typealias EntityID = UInt32

/// Why a machine cannot work. Every case has a plain-English sentence.
public enum BlockReason: Codable, Equatable, Hashable, Sendable {
    case missingInput(ItemID)
    case missingFuel(ItemID)
    case outputFull
    case sourceDepleted(SourceID)
    case noSource
    case noPower

    public func text(_ content: ContentDatabase) -> String {
        switch self {
        case let .missingInput(item), let .missingFuel(item):
            return "Waiting for \(content.plural(item))"
        case .outputFull:
            return "Output is full: nothing is taking it away"
        case let .sourceDepleted(source):
            return "The \(content.source(source)?.name.lowercased() ?? source.rawValue) here is used up"
        case .noSource:
            return "Nothing to gather here"
        case .noPower:
            return "No power"
        }
    }
}

public enum MachineStatus: Codable, Equatable, Hashable, Sendable {
    /// Placed and not doing anything yet, or a building with no work (a crate).
    case idle
    case running
    case blocked(BlockReason)
    /// Still being built by a yard.
    case constructing
    /// A foundation that has everything it needs, or a finished home.
    case complete
}

/// A placed building.
public struct Building: Codable, Equatable, Sendable {
    public let id: EntityID
    public let type: BuildingTypeID
    /// Top-left tile of the footprint.
    public let origin: GridPoint
    public let facing: Direction
    public let placedAtTick: UInt64
    public internal(set) var input = Inventory()
    public internal(set) var output = Inventory()
    /// True while a batch is being made.
    public internal(set) var crafting = false
    /// Ticks of work on the current batch.
    public internal(set) var progress = 0
    public internal(set) var status = MachineStatus.idle
    /// Why it could not start the last time it tried, and for how many ticks.
    public internal(set) var waitReason: BlockReason?
    public internal(set) var waitingTicks = 0
    /// For a yard: the home it is building now.
    public internal(set) var job: EntityID?
    /// Ticks left before a yard-built home is finished.
    public internal(set) var buildRemaining = 0
    public internal(set) var rates: RateTracker
    /// The belt that last took an item from here. When several belts start at
    /// one building (a splitter), they take turns, so each gets a fair share.
    public internal(set) var lastPullBelt: GridPoint?

    init(id: EntityID, type: BuildingTypeID, origin: GridPoint, facing: Direction, tick: UInt64, rules: GameRules) {
        self.id = id
        self.type = type
        self.origin = origin
        self.facing = facing
        placedAtTick = tick
        rates = RateTracker(startTick: tick, buckets: rules.rateBuckets)
    }

    public func footprint(_ def: BuildingDef) -> [GridPoint] {
        (0..<def.height).flatMap { dy in (0..<def.width).map { dx in GridPoint(origin.x + dx, origin.y + dy) } }
    }

    public func covers(_ point: GridPoint, _ def: BuildingDef) -> Bool {
        point.x >= origin.x && point.y >= origin.y && point.x < origin.x + def.width && point.y < origin.y + def.height
    }

    public var isBuilt: Bool { buildRemaining == 0 }
}
