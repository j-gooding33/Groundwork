/// One goal after the tutorial, from Data/milestones.json.
public struct MilestoneDef: Codable, Equatable, Sendable {
    public var id: String
    /// Shown in the goal bar: "Grow to 10 cottages".
    public var text: String
    /// A tutorial condition, usually one that counts ("count:cottage:10").
    public var when: String
    /// How to get there, shown as a tip when the goal appears.
    public var tip: String
    /// What the town is called from here on ("Village").
    public var title: String?
}

public struct MilestoneList: Codable, Equatable, Sendable {
    /// The town's name before any milestone with a title.
    public var startTitle: String
    public var milestones: [MilestoneDef]
}

/// Milestones reached so far. Saved with the world.
public struct MilestoneState: Codable, Equatable, Sendable {
    public internal(set) var done: [String] = []
    /// Milestones whose tip the player has put away.
    public internal(set) var tipsDismissed: [String] = []
}

/// Gives a goal-less world something to aim for: one milestone at a time,
/// celebrated when reached, with the town's title growing as it does.
enum MilestoneRunner {
    static func current(world: World, content: ContentDatabase) -> MilestoneDef? {
        guard let state = world.milestones else { return nil }
        return content.milestones?.milestones.first { !state.done.contains($0.id) }
    }

    static func update(_ world: inout World, content: ContentDatabase, events: inout [GameEvent]) {
        guard let milestone = current(world: world, content: content),
              let condition = TutorialCondition(milestone.when) else { return }
        let seen = (world.hints?.seen ?? []) + (world.level?.seen ?? [])
        guard LevelRunner.holds(condition, seen: { seen.contains($0) }, world: world, content: content) else { return }
        world.milestones?.done.append(milestone.id)
        events.append(.milestoneReached(milestone.id))
    }

    static func progress(world: World, content: ContentDatabase) -> GoalProgress? {
        guard let milestone = current(world: world, content: content),
              let condition = TutorialCondition(milestone.when) else { return nil }
        let amount = LevelRunner.amount(of: condition, world: world, content: content) ?? (0, 1)
        return GoalProgress(text: milestone.text, current: min(amount.current, amount.target), target: amount.target)
    }

    /// "Village", from the last milestone reached that names the town.
    static func title(world: World, content: ContentDatabase) -> String? {
        guard let state = world.milestones, let list = content.milestones else { return nil }
        return list.milestones.last { state.done.contains($0.id) && $0.title != nil }?.title ?? list.startTitle
    }
}
