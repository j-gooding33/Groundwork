/// Runs world logic after every command and tick: records what happened,
/// tracks the chapter goal, moves the tutorial on, and opens chapters. Driven
/// only by world state and events, so it is as deterministic as the simulation.
enum LevelRunner {
    /// Sets up a new world and begins a chapter. Starting later than chapter 0
    /// gives everything the earlier chapters would have (unlocks, belts,
    /// buildings, drawn land) without their tutorials.
    static func start(_ level: LevelDef, chapter: Int, world: inout World, content: ContentDatabase,
                      events: inout [GameEvent]) {
        world.unlocked = level.unlocked
        world.beltsAvailable = level.beltsAvailable
        world.housingPlots = level.housingPlots
        for item in level.preplaced {
            Commands.insertBuilding(item.building, at: item.at, facing: .south, world: &world, content: content)
        }
        world.level = LevelState(level: level.id)
        let first = min(max(chapter, 0), level.chapters.count - 1)
        for earlier in level.chapters.prefix(first) {
            openUp(earlier, level: level, world: &world, content: content)
            for step in steps(earlier, content) { applyGrant(step, world: &world) }
        }
        begin(first, level: level, world: &world, content: content, events: &events)
    }

    /// Gives what a chapter opens up: unlocks, belt tiles, buildings, drawn land.
    private static func openUp(_ chapter: ChapterDef, level: LevelDef, world: inout World, content: ContentDatabase) {
        if chapter.unlockAll == true {
            world.unlocked = nil
        } else if let unlock = chapter.unlock, var unlocked = world.unlocked {
            for type in unlock where !unlocked.contains(type) { unlocked.append(type) }
            world.unlocked = unlocked
        }
        if chapter.unlimitedBelts == true {
            world.beltsAvailable = nil
        } else if let tiles = chapter.beltTiles, let available = world.beltsAvailable {
            world.beltsAvailable = available + tiles
        }
        world.revealed = chapter.reveal.map { Reveal(center: level.revealCenter, radius: $0) }
        world.index = WorldIndex(world: world, content: content)
        for item in chapter.preplaced ?? [] {
            guard let def = content.building(item.building),
                  let at = nearestFree(def, to: item.at, world: world, content: content) else { continue }
            Commands.insertBuilding(item.building, at: at, facing: .south, world: &world, content: content)
        }
    }

    /// The chapter's spot for a building, or the closest free one if the
    /// player has built there already.
    private static func nearestFree(_ def: BuildingDef, to point: GridPoint, world: World,
                                    content: ContentDatabase) -> GridPoint? {
        for ring in 0...4 {
            for dy in -ring...ring {
                for dx in -ring...ring where max(abs(dx), abs(dy)) == ring {
                    let at = GridPoint(point.x + dx, point.y + dy)
                    if Commands.placementProblem(def, at: at, world: world, content: content) == nil { return at }
                }
            }
        }
        return nil
    }

    /// Makes `index` the current chapter and shows its first step.
    private static func begin(_ index: Int, level: LevelDef, world: inout World, content: ContentDatabase,
                              events: inout [GameEvent]) {
        let chapter = level.chapters[index]
        openUp(chapter, level: level, world: &world, content: content)
        world.level?.chapter = index
        world.level?.step = 0
        world.level?.seen = []
        world.level?.goalReached = false
        events.append(.chapterStarted(index))
        if let step = steps(chapter, content).first {
            enter(step, world: &world, events: &events)
        }
    }

    /// Moves on to the next chapter once the current goal is met.
    static func beginNextChapter(world: inout World, content: ContentDatabase, events: inout [GameEvent]) -> Bool {
        guard let state = world.level, state.goalReached, let level = content.level(state.level),
              state.chapter + 1 < level.chapters.count else { return false }
        begin(state.chapter + 1, level: level, world: &world, content: content, events: &events)
        return true
    }

    static func chapter(world: World, content: ContentDatabase) -> ChapterDef? {
        guard let state = world.level, let level = content.level(state.level),
              level.chapters.indices.contains(state.chapter) else { return nil }
        return level.chapters[state.chapter]
    }

    static func nextChapter(world: World, content: ContentDatabase) -> ChapterDef? {
        guard let state = world.level, let level = content.level(state.level),
              level.chapters.indices.contains(state.chapter + 1) else { return nil }
        return level.chapters[state.chapter + 1]
    }

    static func steps(_ chapter: ChapterDef, _ content: ContentDatabase) -> [TutorialStep] {
        chapter.tutorial.flatMap { content.tutorials[$0] } ?? []
    }

    static func currentSteps(world: World, content: ContentDatabase) -> [TutorialStep] {
        chapter(world: world, content: content).map { steps($0, content) } ?? []
    }

    static func currentStep(world: World, content: ContentDatabase) -> TutorialStep? {
        guard let state = world.level else { return nil }
        let all = currentSteps(world: world, content: content)
        return all.indices.contains(state.step) ? all[state.step] : nil
    }

    static func goalProgress(world: World, content: ContentDatabase) -> GoalProgress? {
        guard let goal = chapter(world: world, content: content)?.goal else { return nil }
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
            for key in keys(for: event, world: world) { state.record(key) }
            if case let .buildingPlaced(id, type) = event, !state.stocked.contains(type), let i = world.buildingIndex(id) {
                let stock = level.firstPlacementStock.filter { $0.building == type }
                if !stock.isEmpty {
                    for item in stock { world.buildings[i].input.add(item.item, item.count) }
                    state.stocked.append(type)
                }
            }
        }

        if !state.goalReached, let progress = goalProgress(world: world, content: content), progress.isComplete {
            state.goalReached = true
            state.record(TutorialCondition.goal.key)
            events.append(.goalReached(level.id))
            events.append(.chapterComplete(state.chapter))
        }

        world.level = state
        advanceSteps(world: &world, content: content, events: &events)
    }

    /// The condition keys an event satisfies, such as "placed:clay_pit" and
    /// "delivered:clay:belt". Shared by the tutorial and the hints.
    static func keys(for event: GameEvent, world: World) -> [String] {
        switch event {
        case let .buildingPlaced(_, type):
            return [TutorialCondition.placed(type).key]
        case let .itemProduced(_, item, _):
            return [TutorialCondition.produced(item).key]
        case let .itemDelivered(id, item, via):
            var keys = [TutorialCondition.delivered(item, qualifier: nil).key,
                        TutorialCondition.delivered(item, qualifier: via == .hand ? "hand" : "belt").key]
            if let type = world.building(id)?.type {
                keys.append(TutorialCondition.delivered(item, qualifier: type.rawValue).key)
            }
            return keys
        case let .statusChanged(_, .blocked(reason)):
            return reason.waitingItem.map { [TutorialCondition.waiting($0).key] } ?? []
        default:
            return []
        }
    }

    /// Whether a condition holds now: live checks look at the world, the rest
    /// at what has been recorded.
    static func holds(_ condition: TutorialCondition, seen: (String) -> Bool, world: World,
                      content: ContentDatabase) -> Bool {
        switch condition {
        case .wait:
            return true
        case let .count(type, n):
            return world.buildings.filter { $0.type == type && $0.isBuilt }.count >= n
        case let .linked(from, to):
            return isLinked(from, to, world: world, content: content)
        case let .slow(type):
            return world.buildings.contains { b in
                b.type == type && Trace.run(.building(b.id), world: world, content: content).root.state == .slow
            }
        default:
            return seen(condition.key)
        }
    }

    /// Moves past every step whose condition holds and whose minimum time is up.
    static func advanceSteps(world: inout World, content: ContentDatabase, events: inout [GameEvent]) {
        guard let level = world.level.flatMap({ content.level($0.level) }) else { return }
        let all = currentSteps(world: world, content: content)
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
        return holds(condition, seen: state.hasSeen, world: world, content: content)
    }

    /// True if a belt runs from a building of type `from` into one of type `to`.
    static func isLinked(_ from: BuildingTypeID, _ to: BuildingTypeID, world: World, content: ContentDatabase) -> Bool {
        world.buildings.contains { target in
            target.type == to && BeltSystem.feeders(of: target, in: world, content: content).contains {
                world.building($0)?.type == from
            }
        }
    }

    /// A belt an earlier step of this chapter asked for that is gone now (the
    /// player undid or removed it), so the tutorial can ask for it again.
    static func brokenLink(world: World, content: ContentDatabase) -> (from: BuildingTypeID, to: BuildingTypeID)? {
        guard let state = world.level, state.step < currentSteps(world: world, content: content).count else { return nil }
        for step in currentSteps(world: world, content: content).prefix(state.step) {
            if case let .linked(from, to)? = TutorialCondition(step.when),
               !isLinked(from, to, world: world, content: content) {
                return (from, to)
            }
        }
        return nil
    }

    /// Records something the player did outside the simulation (used Trace,
    /// panned the map) and lets the tutorial react.
    static func note(_ key: String, world: inout World, content: ContentDatabase, events: inout [GameEvent]) {
        guard var state = world.level, !state.hasSeen(key) else { return }
        state.record(key)
        world.level = state
        advanceSteps(world: &world, content: content, events: &events)
    }

    /// Finishes the chapter's remaining steps, giving their unlocks and belt
    /// tiles so nothing is held back.
    static func skipTutorial(world: inout World, content: ContentDatabase, events: inout [GameEvent]) {
        guard let state = world.level, let level = content.level(state.level) else { return }
        let all = currentSteps(world: world, content: content)
        guard state.step < all.count else { return }
        for step in all[(state.step + 1)...] { applyGrant(step, world: &world) }
        world.level?.step = all.count
        events.append(.tutorialFinished(level.id))
    }

    private static func applyGrant(_ step: TutorialStep, world: inout World) {
        if let tiles = step.grant?.beltTiles, let available = world.beltsAvailable {
            world.beltsAvailable = available + tiles
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
