import GroundworkCore

/// One button in the build palette on the left edge.
public struct PaletteEntry: Equatable, Sendable {
    public var tool: Tool
    public var title: String
    /// Atlas sprite to show on the button.
    public var sprite: String
    public var isSelected: Bool
    /// Belt tiles left, shown on the belt button.
    public var badge: String?
}

public struct TutorialBubble: Equatable, Sendable {
    /// The step's id, so the app can remember which bubble was tucked away.
    public var id: String
    public var text: String
    public var tile: GridPoint?
    /// Buildings to outline.
    public var buildings: [EntityID]
    /// A control to pulse: "build", "trace" or "undo".
    public var control: String?
}

/// The context panel on the right edge for the selected building.
public struct SelectionPanel: Equatable, Sendable {
    public var id: EntityID
    public var title: String
    public var status: String
    public var isBlocked: Bool
    public var lines: [String]
    public var canPickUp: Bool
}

/// A line of the Trace overlay between two buildings, coloured by the state
/// of the upstream step.
public struct TraceLine: Equatable, Sendable {
    public var from: ScenePoint
    public var to: ScenePoint
    public var state: TraceState
}

public enum ModeTab: String, Equatable, Sendable, CaseIterable {
    case build, trace, undo, demolish, speed
}

/// Everything the SwiftUI overlay shows, worked out from the session in one place.
public struct HUDModel: Equatable, Sendable {
    public var goal: GoalProgress?
    public var goalFraction: Double
    public var clock: String
    public var palette: [PaletteEntry]
    public var tabs: [ModeTab]
    public var tutorial: TutorialBubble?
    public var selection: SelectionPanel?
    public var hand: String?
    public var traceLines: [TraceLine]
    /// A gentle nudge when a machine has been stuck a while and nobody is
    /// looking at it with Trace. Never shown during a tutorial step.
    public var hint: String?
    /// Above the top of the building Trace says to fix (or nearest to it).
    public var traceMarker: ScenePoint?
    public var levelComplete: Bool
    public var canUndo: Bool
    public var paused: Bool

    public init(session: GameSession, input: InputController) {
        let world = session.world
        let content = session.content
        goal = session.goal
        goalFraction = goal.map { Double($0.current) / Double(max($0.target, 1)) } ?? 0
        clock = DayNight(tick: world.tick).clockText
        levelComplete = session.isGoalReached
        canUndo = session.canUndo
        paused = session.isPausedByTutorial

        // Palette: unlocked buildings that the player places, then the belt.
        let placeable = content.buildings.filter { def in
            !content.buildings.contains { $0.builds == def.id }
        }
        let unlocked = world.unlocked.map(Set.init)
        palette = placeable
            .filter { unlocked?.contains($0.id) ?? true }
            .sorted { ($0.level, $0.name) < ($1.level, $1.name) }
            .map { PaletteEntry(tool: .build($0.id), title: $0.name, sprite: $0.id.rawValue,
                                isSelected: input.tool == .build($0.id), badge: nil) }
        if world.beltsAvailable.map({ $0 > 0 }) ?? true || !world.belts.isEmpty {
            palette.append(PaletteEntry(tool: .belt, title: "Belt", sprite: "icon_belt",
                                        isSelected: input.tool == .belt,
                                        badge: world.beltsAvailable.map(String.init)))
        }

        // Three buttons to start; more once the tutorial is done.
        let tutorialDone = session.tutorialStep == nil
        tabs = tutorialDone ? ModeTab.allCases : [.build, .trace, .undo]

        if let step = session.tutorialStep {
            let outlined = step.highlight?.building.map { type in
                world.buildings.filter { $0.type == type }.map(\.id)
            } ?? []
            tutorial = TutorialBubble(id: step.id, text: step.text, tile: step.highlight?.tile,
                                      buildings: outlined, control: step.highlight?.ui)
        }

        hand = world.hand.map { "Carrying \($0.count) \(content.plural($0.item))" }

        if let id = input.selection, let building = world.building(id) {
            selection = Self.panel(for: building, session: session)
        }
        traceLines = input.trace.map { Self.lines(for: $0, world: world, content: content) } ?? []
        if tutorial == nil, input.trace == nil, Self.hasStuckMachine(world, content: content) {
            hint = "Something has stopped.\nTap Trace, then the dim building."
        }
        if let trace = input.trace, trace.firstBroken != nil, let id = trace.jumpTarget,
           let b = world.building(id), let def = content.building(b.type) {
            let c = Camera.center(of: b.origin, w: def.width, h: def.height, mapHeight: world.map.height)
            traceMarker = ScenePoint(c.x, c.y + Double(def.height) * Camera.tile / 2)
        }
    }

    /// Ticks a machine must wait for an input (or a used-up source) before
    /// the hint appears: 30 seconds. A full output is left alone, because in a
    /// working factory the step before a bottleneck always backs up.
    public static let stuckTicks = 300

    static func hasStuckMachine(_ world: World, content: ContentDatabase) -> Bool {
        world.buildings.contains { b in
            guard let kind = content.building(b.type)?.kind, kind == .gatherer || kind == .processor,
                  let reason = b.waitReason, b.waitingTicks >= stuckTicks else { return false }
            switch reason {
            case .missingInput, .missingFuel, .sourceDepleted, .noSource: return true
            case .outputFull, .noPower: return false
            }
        }
    }

    static func panel(for building: Building, session: GameSession) -> SelectionPanel {
        let content = session.content
        let def = content.building(building.type)
        var lines: [String] = []
        for rate in session.rates(of: building.id) {
            let plural = content.plural(rate.item)
            if rate.made > 0 { lines.append("Makes \(rate.made) \(plural) a minute") }
            if rate.used > 0 { lines.append("Uses \(rate.used) \(plural) a minute") }
            if let seconds = rate.runsOutInSeconds {
                lines.append(seconds < 5 ? "Out of \(plural) now" : "\(plural.capitalizedFirst) run out in \(seconds) s")
            }
        }
        let held = building.input.stacks + building.output.stacks
        if !held.isEmpty {
            lines.append("Holding " + held.map { "\($0.count) \(content.plural($0.item))" }.joined(separator: ", "))
        }
        let status: String
        var blocked = false
        switch building.status {
        case .running: status = "Working"
        case let .blocked(reason):
            status = reason.text(content)
            blocked = true
        case .idle:
            if let reason = building.waitReason {
                status = reason.text(content)
                blocked = true
            } else {
                status = def?.kind == .yard ? "Waiting for a steady supply" : "Ready"
            }
        case .constructing: status = "Being built"
        case .complete: status = def?.kind == .home ? "A home for two" : "Complete"
        }
        let takeable = (def?.kind == .gatherer || def?.kind == .processor) ? !building.output.isEmpty
            : def?.kind == .storage ? !building.input.isEmpty : false
        return SelectionPanel(id: building.id, title: def?.name ?? building.type.rawValue, status: status,
                              isBlocked: blocked, lines: lines, canPickUp: takeable)
    }

    /// Lines from each building in the chain to the building it supplies.
    static func lines(for result: TraceResult, world: World, content: ContentDatabase) -> [TraceLine] {
        func center(_ id: EntityID) -> ScenePoint? {
            guard let b = world.building(id), let def = content.building(b.type) else { return nil }
            return Camera.center(of: b.origin, w: def.width, h: def.height, mapHeight: world.map.height)
        }
        var lines: [TraceLine] = []
        func walk(_ node: TraceNode, parent: EntityID?) {
            let here = node.entity ?? parent
            if let id = node.entity, let parent, id != parent, let a = center(id), let b = center(parent) {
                lines.append(TraceLine(from: a, to: b, state: node.state))
            }
            for child in node.children { walk(child, parent: here) }
        }
        walk(result.root, parent: nil)
        return lines
    }
}

/// Saves every 30 seconds of play, and whenever the app goes to the background.
public struct AutosavePolicy: Sendable {
    public static let interval = 30.0
    private var lastSave: Double?

    public init() {}

    /// Call every frame with wall-clock seconds; true means save now.
    public mutating func shouldSave(now: Double) -> Bool {
        guard let last = lastSave else {
            lastSave = now
            return false
        }
        return now - last >= Self.interval
    }

    public mutating func didSave(now: Double) { lastSave = now }
}

extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
