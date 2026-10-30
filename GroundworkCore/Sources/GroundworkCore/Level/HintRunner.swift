/// One tip for a new world, from Data/hints.json. Shown once, when `show`
/// holds, until `done` holds or it has been up long enough.
public struct HintDef: Codable, Equatable, Sendable {
    public var id: String
    public var text: String
    /// When it becomes useful, as a tutorial condition ("placed:clay_pit", "wait").
    public var show: String
    /// What the player does that makes it unnecessary.
    public var done: String
}

/// Which hints a world has shown. Saved with it.
public struct HintState: Codable, Equatable, Sendable {
    /// Condition keys that have happened in this world, sorted.
    public internal(set) var seen: [String] = []
    /// Hints already shown (or skipped because the player already knew).
    public internal(set) var shown: [String] = []
    public internal(set) var current: String?
    public internal(set) var startedTick: UInt64 = 0

    mutating func record(_ key: String) {
        guard let position = seen.firstIndex(where: { $0 >= key }) else { seen.append(key); return }
        if seen[position] != key { seen.insert(key, at: position) }
    }
}

/// Offers the hints in a new world's first hour, one at a time, never
/// blocking anything. Driven only by world state, like the tutorial.
enum HintRunner {
    static func update(_ world: inout World, content: ContentDatabase, newEvents: ArraySlice<GameEvent>) {
        guard var state = world.hints, let def = content.worldGen else { return }
        for event in newEvents {
            for key in LevelRunner.keys(for: event, world: world) { state.record(key) }
        }
        func holds(_ text: String) -> Bool {
            guard let condition = TutorialCondition(text) else { return false }
            return LevelRunner.holds(condition, seen: { state.seen.contains($0) }, world: world, content: content)
        }

        if let id = state.current, let hint = content.hints.first(where: { $0.id == id }) {
            if holds(hint.done) || world.tick >= state.startedTick + UInt64(def.hintShowTicks) {
                state.shown.append(id)
                state.current = nil
            }
        }
        if state.current == nil, world.tick < UInt64(def.hintTicks) {
            for hint in content.hints where !state.shown.contains(hint.id) && holds(hint.show) {
                if holds(hint.done) {
                    state.shown.append(hint.id)   // already knows it
                    continue
                }
                state.current = hint.id
                state.startedTick = world.tick
                break
            }
        }
        world.hints = state
    }

    /// Records something the player did outside the simulation.
    static func note(_ key: String, world: inout World) {
        world.hints?.record(key)
    }

    static func dismiss(world: inout World) {
        guard let id = world.hints?.current else { return }
        world.hints?.shown.append(id)
        world.hints?.current = nil
    }
}
