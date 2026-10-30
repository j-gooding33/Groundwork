import GroundworkCore

public enum SoundCue: String, Equatable, Sendable, CaseIterable {
    case place, remove, belt, pickup, drop, produce, chime, blocked, unblocked, goal, tutorial, home
}

/// Moments of feedback the app plays in response to what happened.
public enum Effect: Equatable, Sendable {
    /// A small bounce and a dust puff where a building appeared.
    case placed(EntityID, at: ScenePoint)
    case removed(at: ScenePoint)
    /// A quick squash on the building that just made something.
    case squash(EntityID)
    /// "+1 brick" floating up, only for the first few of each item.
    case floatText(String, at: ScenePoint)
    /// The first building of each type wears its name and what it does for
    /// `nameTagSeconds`, so the player learns what they just placed.
    case nameTag(EntityID, name: String, description: String, at: ScenePoint)
    case haptic(Haptic)
    case sound(SoundCue)
    /// A warm light sweep and colour spreading across the map.
    case celebrate
    case musicLayers(Int)
    /// A line across the top for a moment: "Milestone: Grow to 10 cottages".
    case banner(String)
}

/// Decides which effects to play for a batch of game events. Restraint is
/// part of the design: floating numbers only for the first few items, and
/// one sound per kind of thing per batch.
public struct EffectPlanner: Sendable {
    /// Floating "+1"s shown so far, per item.
    private var floats: [ItemID: Int] = [:]
    public static let floatLimit = 5
    public private(set) var musicLayers = 1
    public static let nameTagSeconds = 10.0

    public init() {}

    public mutating func plan(_ events: [GameEvent], session: GameSession) -> [Effect] {
        var effects: [Effect] = []
        var sounds: [SoundCue] = []
        func sound(_ cue: SoundCue) {
            if !sounds.contains(cue) { sounds.append(cue) }
        }
        let world = session.world
        func center(_ id: EntityID) -> ScenePoint? {
            guard let b = world.building(id), let def = session.content.building(b.type) else { return nil }
            return Camera.center(of: b.origin, w: def.width, h: def.height, mapHeight: world.map.height)
        }

        for event in events {
            switch event {
            case let .buildingPlaced(id, type):
                if let c = center(id) {
                    effects.append(.placed(id, at: c))
                    if world.buildings.filter({ $0.type == type }).count == 1, let def = session.content.building(type) {
                        effects.append(.nameTag(id, name: def.name, description: def.description, at: c))
                    }
                }
                sound(.place)
            case .buildingRemoved:
                sound(.remove)
            case .beltLaid:
                sound(.belt)
            case .beltRemoved, .roadRemoved, .truckRouteRemoved:
                sound(.remove)
            case .roadLaid:
                sound(.belt)
            case .truckRouteSet:
                sound(.place)
            case let .itemProduced(id, item, count):
                effects.append(.squash(id))
                let shown = floats[item, default: 0]
                if shown < Self.floatLimit, let c = center(id) {
                    floats[item] = shown + 1
                    effects.append(.floatText("+\(count) \(session.content.plural(item))", at: c))
                    // The first brick ever gets the chime.
                    sound(shown == 0 ? .chime : .produce)
                }
            case let .itemDelivered(_, _, via):
                if via == .hand { sound(.drop) }
            case .statusChanged(_, .blocked):
                sound(.blocked)
            case .statusChanged(_, .running):
                break
            case .statusChanged:
                break
            case .constructionCompleted:
                sound(.chime)
            case let .homeStarted(id, _):
                if let c = center(id) { effects.append(.placed(id, at: c)) }
            case .homeCompleted:
                sound(.home)
                musicLayers = min(musicLayers + 1, 4)
                effects.append(.musicLayers(musicLayers))
            case .sourceDepleted:
                break
            case .tutorialStep:
                sound(.tutorial)
            case .tutorialFinished, .chapterStarted, .chapterComplete:
                break
            case let .milestoneReached(id):
                let def = session.content.milestones?.milestones.first { $0.id == id }
                var text = def.map { "Milestone: \($0.text)" } ?? "Milestone reached"
                if let title = def?.title { text += ". Now a \(title)!" }
                effects.append(.banner(text))
                effects.append(.haptic(.double))
                effects.append(.celebrate)
                sound(.goal)
            case .goalReached:
                effects.append(.haptic(.double))
                effects.append(.celebrate)
                sound(.goal)
                musicLayers = min(musicLayers + 1, 4)
                effects.append(.musicLayers(musicLayers))
            }
        }
        return effects + sounds.map(Effect.sound)
    }
}

/// The steady machine hum: one layer per running machine, pitched up by how
/// much is being made. A blocked machine goes quiet.
public struct AudioMix: Equatable, Sendable {
    public var runningMachines: Int
    /// 0 to 1, how loud the hum is.
    public var humVolume: Double
    /// Multiplier on the hum's base pitch.
    public var humPitch: Double

    public init(world: World, content: ContentDatabase) {
        let machines = world.buildings.filter { b in
            guard let kind = content.building(b.type)?.kind else { return false }
            return (kind == .gatherer || kind == .processor) && b.status == .running
        }
        runningMachines = machines.count
        humVolume = min(1, Double(machines.count) * 0.18)
        humPitch = 1 + min(0.5, Double(machines.count) * 0.06)
    }
}
