/// Runs level logic after every command and tick: records what happened,
/// tracks the goal, and moves the tutorial on. Driven only by world state and
/// events, so it is as deterministic as the simulation.
enum LevelRunner {
    /// Sets up a new world for a level.
    static func start(_ level: LevelDef, world: inout World, content: ContentDatabase, events: inout [GameEvent]) {
        world.unlocked = level.unlocked
        world.beltsAvailable = level.beltsAvailable
        world.housingPlots = level.housingPlots
        for item in level.preplaced {
            Commands.insertBuilding(item.building, at: item.at, facing: .south, world: &world, content: content)
        }
        world.level = LevelState(level: level.id)
        if let step = steps(level, content).first {
            enter(step, world: &world, events: &events)
        }
    }

    static func steps(_ level: LevelDef, _ content: ContentDatabase) -> [TutorialStep] {
        level.tutorial.flatMap { content.tutorials[$0] } ?? []
    }

    static func currentStep(world: World, content: ContentDatabase) -> TutorialStep? {
        guard let state = world.level, let level = content.level(state.level) else { return nil }
        let all = steps(level, content)
        return all.indices.contains(state.step) ? all[state.step] : nil
    }

    static func goalProgress(world: World, content: ContentDatabase) -> GoalProgress? {
        guard let state = world.level, let level = content.level(state.level) else { return nil }
        let goal = level.goal
        var current = 0
        switch goal.kind {
        case .deliver:
            if let item = goal.item, let to = goal.to {
                current = world.buildings.filter { $0.type == to }.reduce(0) { $0 + $1.input.count(of: item) }
            }
        case .build:
            if let type = goal.building {
                current = world.buildings.filter { $0.type == type && $0.isBuilt }.count
            }
        }
        return GoalProgress(text: goal.text, current: min(current, goal.count), target: goal.count)
    }

    /// Processes events produced since the last update.
    static func update(_ world: inout World, content: ContentDatabase, newEvents: ArraySlice<GameEvent>,
                       events: inout [GameEvent]) {
        guard var state = world.level, let level = content.level(state.level) else { return }

        for event in newEvents {
            switch event {
            case let .buildingPlaced(id, type):
                state.record(TutorialCondition.placed(type).key)
                if !state.stocked.contains(type), let i = world.buildingIndex(id) {
                    let stock = level.firstPlacementStock.filter { $0.building == type }
                    if !stock.isEmpty {
                        for item in stock { world.buildings[i].input.add(item.item, item.count) }
                        state.stocked.append(type)
                    }
                }
            case let .itemProduced(_, item, _):
                state.record(TutorialCondition.produced(item).key)
            case let .itemDelivered(id, item, via):
                state.record(TutorialCondition.delivered(item, qualifier: nil).key)
                state.record(TutorialCondition.delivered(item, qualifier: via == .hand ? "hand" : "belt").key)
                if let type = world.building(id)?.type {
                    state.record(TutorialCondition.delivered(item, qualifier: type.rawValue).key)
                }
            case let .statusChanged(_, .blocked(reason)):
                if let item = reason.waitingItem { state.record(TutorialCondition.waiting(item).key) }
            default:
                break
            }
        }

        if !state.goalReached, let progress = goalProgress(world: world, content: content), progress.isComplete {
            state.goalReached = true
            state.record(TutorialCondition.goal.key)
            events.append(.goalReached(level.id))
        }

        world.level = state
        advanceSteps(level, world: &world, content: content, events: &events)
    }

    /// Moves past every step whose condition holds and whose minimum time is up.
    static func advanceSteps(_ level: LevelDef, world: inout World, content: ContentDatabase,
                             events: inout [GameEvent]) {
        let all = steps(level, content)
        while let index = world.level?.step, all.indices.contains(index),
              isDone(all[index], world: world, content: content) {
            world.level?.step = index + 1
            if all.indices.contains(index + 1) {
                enter(all[index + 1], world: &world, events: &events)
            } else {
                events.append(.tutorialFinished(level.id))
            }
        }
    }

    static func isDone(_ step: TutorialStep, world: World, content: ContentDatabase) -> Bool {
        guard let state = world.level, let condition = TutorialCondition(step.when) else { return false }
        if let wait = step.waitTicks, world.tick < (state.stepStartedTick ?? 0) + UInt64(wait) { return false }
        switch condition {
        case .wait:
            return true
        case let .count(type, n):
            return world.buildings.filter { $0.type == type && $0.isBuilt }.count >= n
        case let .slow(type):
            return world.buildings.contains { b in
                b.type == type && Trace.run(.building(b.id), world: world, content: content).root.state == .slow
            }
        default:
            return state.hasSeen(condition.key)
        }
    }

    /// Records something the player did outside the simulation (used Trace,
    /// panned the map) and lets the tutorial react.
    static func note(_ key: String, world: inout World, content: ContentDatabase, events: inout [GameEvent]) {
        guard var state = world.level, !state.hasSeen(key), let level = content.level(state.level) else { return }
        state.record(key)
        world.level = state
        advanceSteps(level, world: &world, content: content, events: &events)
    }

    /// Finishes every remaining step, giving their unlocks and belt tiles so
    /// nothing is held back.
    static func skipTutorial(world: inout World, content: ContentDatabase, events: inout [GameEvent]) {
        guard let state = world.level, let level = content.level(state.level) else { return }
        let all = steps(level, content)
        guard state.step < all.count else { return }
        for step in all[(state.step + 1)...] { applyGrant(step, world: &world) }
        world.level?.step = all.count
        events.append(.tutorialFinished(level.id))
    }

    private static func applyGrant(_ step: TutorialStep, world: inout World) {
        if let tiles = step.grant?.beltTiles {
            world.beltsAvailable = (world.beltsAvailable ?? 0) + tiles
        }
        if let unlock = step.grant?.unlock, var unlocked = world.unlocked {
            for type in unlock where !unlocked.contains(type) { unlocked.append(type) }
            world.unlocked = unlocked
        }
    }

    private static func enter(_ step: TutorialStep, world: inout World, events: inout [GameEvent]) {
        applyGrant(step, world: &world)
        world.level?.stepStartedTick = world.tick
        events.append(.tutorialStep(step.id))
    }
}
