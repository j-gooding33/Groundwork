/// The fixed-tick simulation. Pure: the next world depends only on the current
/// world and the content, never on wall-clock time or frame rate.
public enum Simulation {
    public static let ticksPerSecond = 10
    public static let ticksPerMinute = ticksPerSecond * 60

    /// Advances the world by exactly one tick. Stages always run in this order,
    /// and buildings always in id order.
    public static func step(_ world: inout World, content: ContentDatabase, events: inout [GameEvent]) {
        world.tick += 1
        regrowSources(&world, content: content)
        Production.step(&world, content: content, events: &events)
        BeltSystem.step(&world, content: content, events: &events)
        DemandRule.step(&world, content: content, events: &events)
        updateStatuses(&world, content: content, events: &events)
    }

    static func regrowSources(_ world: inout World, content: ContentDatabase) {
        for source in content.sources where source.regrowPerMinute > 0 {
            let interval = UInt64(max(1, ticksPerMinute / source.regrowPerMinute))
            if world.tick % interval == 0 { world.map.regrow(source) }
        }
    }

    static func updateStatuses(_ world: inout World, content: ContentDatabase, events: inout [GameEvent]) {
        for i in world.buildings.indices {
            guard let def = content.building(world.buildings[i].type) else { continue }
            let building = world.buildings[i]
            var status = building.status
            switch def.kind {
            case .gatherer, .processor:
                if building.progress > 0 {
                    status = .running
                } else if let reason = building.waitReason, building.waitingTicks >= content.rules.blockGraceTicks {
                    status = .blocked(reason)
                }
            case .construction:
                status = Production.remainingCapacity(of: building, def: def, rules: content.rules) == 0 ? .complete : .idle
            case .home:
                status = building.isBuilt ? .complete : .constructing
            case .storage, .yard:
                status = .idle
            }
            if status != building.status {
                world.buildings[i].status = status
                events.append(.statusChanged(building.id, status))
                if status == .complete && def.kind == .construction {
                    events.append(.constructionCompleted(building.id))
                }
            }
        }
    }
}
