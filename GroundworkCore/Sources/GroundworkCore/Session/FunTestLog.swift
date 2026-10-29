/// Numbers for the design's fun test: how quickly a player gets a belt
/// running, notices a bottleneck and fixes it. Recorded from events, saved
/// with the world, and shown by the app's debug overlay.
///
/// Times are game ticks (10 per second). Game time stops while the first
/// tutorial step waits, so the app should log wall-clock session length itself.
public struct FunTestLog: Codable, Equatable, Sendable {
    /// The first belt laid, and the first item a belt delivered.
    public internal(set) var firstBeltLaidTick: UInt64?
    public internal(set) var firstBeltDeliveryTick: UInt64?
    /// The first time any machine showed as blocked.
    public internal(set) var firstBlockedTick: UInt64?
    /// The first time a blocked machine ran again after the player did something.
    public internal(set) var firstFixTick: UInt64?
    public internal(set) var bottlenecksFixed = 0
    /// Successful player commands.
    public internal(set) var commands = 0

    /// Machines blocked now, with the tick each became blocked, sorted by id.
    private var blockedSince: [BlockedEntry] = []
    private var lastCommandTick: UInt64?

    private struct BlockedEntry: Codable, Equatable, Sendable {
        var id: EntityID
        var tick: UInt64
    }

    public init() {}

    /// Seconds of game time from the start to the first belt delivery.
    public var secondsToFirstBelt: Int? {
        firstBeltDeliveryTick.map { Int($0) / Simulation.ticksPerSecond }
    }

    /// Seconds of game time from the first blocked machine to the first fix.
    public var secondsToFirstFix: Int? {
        guard let blocked = firstBlockedTick, let fixed = firstFixTick, fixed >= blocked else { return nil }
        return Int(fixed - blocked) / Simulation.ticksPerSecond
    }

    mutating func record(_ events: ArraySlice<GameEvent>, tick: UInt64, byPlayer: Bool, succeeded: Bool) {
        if byPlayer && succeeded {
            commands += 1
            lastCommandTick = tick
        }
        for event in events {
            switch event {
            case .beltLaid:
                if byPlayer, firstBeltLaidTick == nil { firstBeltLaidTick = tick }
            case .itemDelivered(_, _, via: .belt):
                if firstBeltDeliveryTick == nil { firstBeltDeliveryTick = tick }
            case let .statusChanged(id, .blocked):
                if firstBlockedTick == nil { firstBlockedTick = tick }
                if !blockedSince.contains(where: { $0.id == id }) {
                    let position = blockedSince.firstIndex { $0.id > id } ?? blockedSince.endIndex
                    blockedSince.insert(BlockedEntry(id: id, tick: tick), at: position)
                }
            case let .statusChanged(id, .running):
                guard let index = blockedSince.firstIndex(where: { $0.id == id }) else { break }
                let since = blockedSince.remove(at: index).tick
                // Only a fix if the player acted while it was stuck; machines
                // that clear on their own (a belt draining) do not count.
                if let command = lastCommandTick, command >= since {
                    bottlenecksFixed += 1
                    if firstFixTick == nil { firstFixTick = tick }
                }
            case let .buildingRemoved(id, _):
                blockedSince.removeAll { $0.id == id }
            default:
                break
            }
        }
    }
}
