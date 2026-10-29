public struct LevelID: StringID {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
}

/// The world the game is played in, from Data/levels.json: one map, played
/// through in chapters. Buildings carry over from chapter to chapter.
public struct LevelDef: Codable, Equatable, Sendable {
    public struct Preplaced: Codable, Equatable, Sendable {
        public var building: BuildingTypeID
        public var at: GridPoint
    }

    /// Items given to the first building of a type the player places, such as
    /// the kiln's starting logs.
    public struct PlacementStock: Codable, Equatable, Sendable {
        public var building: BuildingTypeID
        public var item: ItemID
        public var count: Int
    }

    /// A name written on the map, such as "Clay" over the deposit.
    public struct Landmark: Codable, Equatable, Sendable {
        public var text: String
        public var at: GridPoint
        /// The label goes once a building of this type exists ("Clay" goes
        /// when there is a Clay Pit).
        public var hideWhenBuilt: BuildingTypeID?
        /// The label goes once this chapter (0-based) begins.
        public var untilChapter: Int?
    }

    public var id: LevelID
    public var name: String
    /// Map file, relative to Data/.
    public var map: String
    /// Where the camera starts.
    public var focus: GridPoint
    /// The middle of the drawn land; each chapter's reveal radius grows around it.
    public var revealCenter: GridPoint
    /// Buildings in the palette at the start; chapters and tutorial steps unlock more.
    public var unlocked: [BuildingTypeID]
    public var beltsAvailable: Int?
    public var preplaced: [Preplaced]
    public var firstPlacementStock: [PlacementStock]
    public var housingPlots: [GridPoint]
    public var landmarks: [Landmark]
    public var chapters: [ChapterDef]
}

/// One chapter of the world: a goal, its guided steps, and what it opens up.
public struct ChapterDef: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    /// Nil for free build, which has no goal.
    public var goal: GoalDef?
    /// Key into tutorial.json.
    public var tutorial: String?
    public var unlock: [BuildingTypeID]?
    /// Unlock every building.
    public var unlockAll: Bool?
    public var beltTiles: Int?
    /// No more limit on belt tiles.
    public var unlimitedBelts: Bool?
    /// Buildings that appear when the chapter begins.
    public var preplaced: [LevelDef.Preplaced]?
    /// How far the drawn land reaches from the reveal centre. Nil means the whole map.
    public var reveal: Int?
}

public struct GoalDef: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        /// Deliver `count` of `item` into buildings of type `to`.
        case deliver
        /// Have `count` finished buildings of type `building`.
        case build
    }

    public var kind: Kind
    public var text: String
    public var count: Int
    public var item: ItemID?
    public var to: BuildingTypeID?
    public var building: BuildingTypeID?
}

/// One guided step. Text is at most two short lines.
public struct TutorialStep: Codable, Equatable, Sendable {
    public struct Highlight: Codable, Equatable, Sendable {
        /// A tile to outline, usually where to place something.
        public var tile: GridPoint?
        /// Outline every building of this type.
        public var building: BuildingTypeID?
        /// A UI control to pulse: "build", "trace" or "undo".
        public var ui: String?
    }

    public struct Grant: Codable, Equatable, Sendable {
        public var beltTiles: Int?
        public var unlock: [BuildingTypeID]?
    }

    public var id: String
    public var text: String
    public var highlight: Highlight?
    /// What finishes the step, e.g. "placed:clay_pit". See `TutorialCondition`.
    public var when: String
    /// Given when the step begins.
    public var grant: Grant?
    /// Hold the simulation while this step shows.
    public var pauseSim: Bool?
    /// Show the step for at least this many ticks before it can finish, so a
    /// quick step is not gone before it can be read.
    public var waitTicks: Int?
}

/// What a tutorial step waits for. Written in JSON as a short string:
///
/// - `placed:<building>` the player or a yard placed one
/// - `produced:<item>` any building made one
/// - `delivered:<item>`, `delivered:<item>:hand`, `delivered:<item>:belt`,
///   `delivered:<item>:<building>` an item arrived (by that means, or at that building)
/// - `waiting:<item>` a machine is blocked waiting for that item
/// - `slow:<building>` Trace judges a building of that type slow right now
/// - `traced:<building>` the player used Trace on a building of that type
/// - `ui:<name>` the app reported a UI action, such as `ui:panned`
/// - `count:<building>:<n>` there are at least n finished buildings of that type
/// - `wait` nothing: the step finishes after its `waitTicks` (a tip)
/// - `goal` the level goal is reached
public enum TutorialCondition: Equatable, Sendable {
    case placed(BuildingTypeID)
    case produced(ItemID)
    case delivered(ItemID, qualifier: String?)
    case waiting(ItemID)
    case slow(BuildingTypeID)
    case traced(BuildingTypeID)
    case ui(String)
    case count(BuildingTypeID, Int)
    case wait
    case goal

    public init?(_ text: String) {
        let parts = text.split(separator: ":").map(String.init)
        switch (parts.first, parts.count) {
        case ("placed", 2): self = .placed(BuildingTypeID(rawValue: parts[1]))
        case ("produced", 2): self = .produced(ItemID(rawValue: parts[1]))
        case ("delivered", 2): self = .delivered(ItemID(rawValue: parts[1]), qualifier: nil)
        case ("delivered", 3): self = .delivered(ItemID(rawValue: parts[1]), qualifier: parts[2])
        case ("waiting", 2): self = .waiting(ItemID(rawValue: parts[1]))
        case ("slow", 2): self = .slow(BuildingTypeID(rawValue: parts[1]))
        case ("traced", 2): self = .traced(BuildingTypeID(rawValue: parts[1]))
        case ("ui", 2) where !parts[1].isEmpty: self = .ui(parts[1])
        case ("count", 3):
            guard let n = Int(parts[2]), n > 0 else { return nil }
            self = .count(BuildingTypeID(rawValue: parts[1]), n)
        case ("wait", 1): self = .wait
        case ("goal", 1): self = .goal
        default: return nil
        }
    }

    /// The key recorded in `LevelState.seen` when this happens.
    public var key: String {
        switch self {
        case let .placed(type): return "placed:\(type)"
        case let .produced(item): return "produced:\(item)"
        case let .delivered(item, nil): return "delivered:\(item)"
        case let .delivered(item, qualifier?): return "delivered:\(item):\(qualifier)"
        case let .waiting(item): return "waiting:\(item)"
        case let .slow(type): return "slow:\(type)"
        case let .traced(type): return "traced:\(type)"
        case let .ui(name): return "ui:\(name)"
        case let .count(type, n): return "count:\(type):\(n)"
        case .wait: return "wait"
        case .goal: return "goal"
        }
    }
}

/// Progress through the world. Saved with it.
public struct LevelState: Codable, Equatable, Sendable {
    public var level: LevelID
    /// The chapter being played, 0-based.
    public internal(set) var chapter: Int
    /// Index of the chapter's tutorial step showing now; equal to the step count when done.
    public internal(set) var step: Int
    /// Everything that has happened this chapter, as condition keys, sorted.
    public internal(set) var seen: [String]
    /// The current chapter's goal is met.
    public internal(set) var goalReached: Bool
    /// Building types that already got their first-placement stock.
    public internal(set) var stocked: [BuildingTypeID]
    /// The tick the current step began, for `waitTicks`.
    public internal(set) var stepStartedTick: UInt64?

    init(level: LevelID) {
        self.level = level
        chapter = 0
        step = 0
        seen = []
        goalReached = false
        stocked = []
    }

    public func hasSeen(_ key: String) -> Bool { seen.contains(key) }

    mutating func record(_ key: String) {
        guard let position = seen.firstIndex(where: { $0 >= key }) else { seen.append(key); return }
        if seen[position] != key { seen.insert(key, at: position) }
    }
}

public struct GoalProgress: Equatable, Sendable {
    public var text: String
    public var current: Int
    public var target: Int
    public var isComplete: Bool { current >= target }
}
