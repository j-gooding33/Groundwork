import GroundworkCore

/// The tool in the player's hand.
public enum Tool: Equatable, Sendable {
    /// Tap to carry and inspect; drag to pan.
    case none
    case build(BuildingTypeID)
    /// Drag to lay a belt.
    case belt
    case demolish
    case trace
}

public enum Haptic: Equatable, Sendable {
    case light, double, warning
}

/// What the app should show or play after a gesture.
public struct Feedback: Equatable, Sendable {
    /// A short sentence for a toast.
    public var toast: String?
    public var haptic: Haptic?
    /// Centre the camera here.
    public var focus: GridPoint?

    public init(toast: String? = nil, haptic: Haptic? = nil, focus: GridPoint? = nil) {
        self.toast = toast
        self.haptic = haptic
        self.focus = focus
    }

    public static let none = Feedback()
}

/// Turns taps and drags on tiles into GameSession commands. One clear
/// interaction per tool, an obvious way to cancel, no confirmation dialogs.
public struct InputController: Sendable {
    public private(set) var tool: Tool = .none
    /// The building whose panel is open.
    public private(set) var selection: EntityID?
    /// The ghost path while dragging a belt.
    public private(set) var ghost: [GridPoint] = []
    public private(set) var dragStart: GridPoint?
    /// The chain shown by the Trace tool.
    public private(set) var trace: TraceResult?
    /// Whether rate labels are drawn over buildings.
    public private(set) var showRates = false

    public init() {}

    /// Whether a one-finger drag should lay something instead of panning.
    public var dragDraws: Bool { tool == .belt }

    /// Tapping a palette button: selects the tool, or puts it down if it was
    /// already selected.
    public mutating func choose(_ tool: Tool) {
        self.tool = self.tool == tool ? .none : tool
        ghost = []
        dragStart = nil
        if self.tool != .trace { trace = nil }
    }

    /// Selects a tool, staying on it if it is already selected (palette
    /// buttons use `choose`, which toggles).
    public mutating func use(_ tool: Tool) {
        if self.tool != tool { choose(tool) }
    }

    /// Back to no tool, clearing previews.
    public mutating func cancel() {
        tool = .none
        ghost = []
        dragStart = nil
        trace = nil
    }

    public mutating func clearSelection() { selection = nil }

    public mutating func toggleRates() { showRates.toggle() }

    /// Drops a half-dragged belt without laying it (a second finger came down).
    public mutating func cancelDrag() {
        ghost = []
        dragStart = nil
    }

    // MARK: Taps

    public mutating func tap(_ tile: GridPoint, session: GameSession) -> Feedback {
        switch tool {
        case let .build(type):
            guard let def = session.content.building(type) else { return .none }
            // Centre larger footprints under the finger.
            let origin = GridPoint(tile.x - (def.width - 1) / 2, tile.y - (def.height - 1) / 2)
            return result(session.place(type, at: origin), success: .light)

        case .belt:
            // Tap one building, then another: the same belt as dragging between them.
            let point = Self.snap(tile, session: session)
            guard let start = dragStart else {
                guard session.world.building(at: point) != nil else {
                    return Feedback(toast: "Tap a building to start a belt, or drag from it")
                }
                dragStart = point
                ghost = session.previewBelt(from: point, to: point) ?? []
                return Feedback(toast: "Now tap where the belt should go", haptic: .light)
            }
            dragStart = nil
            ghost = []
            if session.world.building(at: point).map({ $0.id }) == session.world.building(at: start)?.id {
                return .none   // tapped the same building again: never mind
            }
            return layBelt(from: start, to: point, session: session)

        case .demolish:
            if let building = session.world.building(at: tile) {
                if selection == building.id { selection = nil }
                return result(session.remove(building.id), success: .light)
            }
            if session.world.belt(at: tile) != nil {
                return result(session.removeBelt(at: tile), success: .light)
            }
            return .none

        case .trace:
            guard let building = session.world.building(at: tile) else {
                trace = nil
                return .none
            }
            let result = session.trace(.building(building.id))
            trace = result
            selection = building.id
            let focus = result.jumpTarget.flatMap { session.world.building($0)?.origin }
            return Feedback(toast: result.firstBroken.map(\.reason), focus: focus == building.origin ? nil : focus)

        case .none:
            return carryOrSelect(tile, session: session)
        }
    }

    /// With no tool, tapping a building moves items by hand: drop what you
    /// hold, or pick up what it has made. Either way its panel opens.
    private mutating func carryOrSelect(_ tile: GridPoint, session: GameSession) -> Feedback {
        guard let building = session.world.building(at: tile) else {
            selection = nil
            return .none
        }
        selection = building.id
        if session.world.hand != nil {
            switch session.drop(into: building.id) {
            case .ok: return Feedback(haptic: .light)
            case let .rejected(error):
                // Holding something it does not take: pick up from it instead if it can.
                if session.pickUp(from: building.id) == .ok { return Feedback(haptic: .light) }
                return Feedback(toast: error.message)
            }
        }
        if session.pickUp(from: building.id) == .ok { return Feedback(haptic: .light) }
        return .none
    }

    // MARK: Long press

    /// Opens the building's panel whatever the tool.
    public mutating func longPress(_ tile: GridPoint, session: GameSession) -> Feedback {
        selection = session.world.building(at: tile)?.id
        return selection == nil ? .none : Feedback(haptic: .light)
    }

    // MARK: Belt drags

    public mutating func dragBegan(_ tile: GridPoint, session: GameSession) {
        guard tool == .belt else { return }
        let start = Self.snap(tile, session: session)
        dragStart = start
        ghost = session.previewBelt(from: start, to: start) ?? []
    }

    public mutating func dragMoved(_ tile: GridPoint, session: GameSession) {
        guard tool == .belt, let start = dragStart else { return }
        ghost = session.previewBelt(from: start, to: Self.snap(tile, session: session)) ?? []
    }

    public mutating func dragEnded(_ tile: GridPoint, session: GameSession) -> Feedback {
        guard tool == .belt, let start = dragStart else { return .none }
        dragStart = nil
        ghost = []
        let end = Self.snap(tile, session: session)
        guard start != end else { return Feedback(toast: "Drag from a building to lay a belt") }
        return layBelt(from: start, to: end, session: session)
    }

    private mutating func layBelt(from start: GridPoint, to end: GridPoint, session: GameSession) -> Feedback {
        let deadBefore = SceneBuilder.deadEnds(session.world)
        var feedback = result(session.layBelt(from: start, to: end), success: .light)
        if feedback.toast == nil, SceneBuilder.deadEnds(session.world).contains(where: { !deadBefore.contains($0) }) {
            feedback.toast = "That belt doesn't reach anything yet"
        }
        if session.world.beltsAvailable == 0 { tool = .none }
        return feedback
    }

    /// Where a finger "means": the building or belt under it, or else the
    /// building it is next to. Buildings are drawn standing up, so a finger on
    /// the top of a kiln is really on the tile above it; letting go there
    /// should still reach the kiln, not leave the belt stopped on the grass.
    public static func snap(_ tile: GridPoint, session: GameSession) -> GridPoint {
        let world = session.world
        if world.building(at: tile) != nil || world.belt(at: tile) != nil { return tile }
        let order = [(0, 1), (0, -1), (-1, 0), (1, 0), (-1, 1), (1, 1), (-1, -1), (1, -1)]
        for (dx, dy) in order {
            let p = GridPoint(tile.x + dx, tile.y + dy)
            if world.building(at: p) != nil { return p }
        }
        return tile
    }

    private func result(_ result: CommandResult, success: Haptic) -> Feedback {
        switch result {
        case .ok: return Feedback(haptic: success)
        case let .rejected(error): return Feedback(toast: error.message, haptic: .warning)
        }
    }
}
