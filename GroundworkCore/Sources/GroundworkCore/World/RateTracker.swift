/// Counts items made, used and received over a rolling window, so a building
/// can show "12 per minute" and Trace can spot a slow input.
///
/// The window is split into buckets. Each position in the ring remembers which
/// absolute bucket it holds, so stale counts are ignored without a cleanup pass.
public struct RateTracker: Codable, Equatable, Sendable {
    public struct Entry: Codable, Equatable, Sendable {
        public var item: ItemID
        public var made: [Int]
        public var used: [Int]
        public var received: [Int]
    }

    public enum Kind: Sendable { case made, used, received }

    public private(set) var startTick: UInt64
    private var bucketIDs: [UInt64]
    private var entries: [Entry] = []

    public init(startTick: UInt64, buckets: Int) {
        self.startTick = startTick
        bucketIDs = Array(repeating: UInt64.max, count: buckets)
    }

    mutating func record(_ kind: Kind, _ item: ItemID, _ count: Int, tick: UInt64, rules: GameRules) {
        guard count > 0, !bucketIDs.isEmpty else { return }
        let bucket = tick / UInt64(rules.rateBucketTicks)
        let position = Int(bucket % UInt64(bucketIDs.count))
        if bucketIDs[position] != bucket {
            bucketIDs[position] = bucket
            for index in entries.indices {
                entries[index].made[position] = 0
                entries[index].used[position] = 0
                entries[index].received[position] = 0
            }
        }
        let index = entryIndex(for: item)
        switch kind {
        case .made: entries[index].made[position] += count
        case .used: entries[index].used[position] += count
        case .received: entries[index].received[position] += count
        }
    }

    /// Items per minute over the window, or over the building's lifetime if it is younger.
    public func perMinute(_ kind: Kind, _ item: ItemID, tick: UInt64, rules: GameRules) -> Int {
        let count = countInWindow(kind, item, tick: tick, rules: rules)
        let covered = coveredTicks(tick: tick, rules: rules)
        return Int(UInt64(count) * UInt64(Simulation.ticksPerMinute) / covered)
    }

    /// How many ticks the window's counts actually span: from the start of the
    /// oldest bucket in the window (or the building's first working tick) to now.
    func coveredTicks(tick: UInt64, rules: GameRules) -> UInt64 {
        let bucketTicks = UInt64(rules.rateBucketTicks)
        let current = tick / bucketTicks
        let oldest = current >= UInt64(bucketIDs.count - 1) ? current - UInt64(bucketIDs.count - 1) : 0
        let sinceWindow = tick - oldest * bucketTicks + 1
        let sincePlaced = tick > startTick ? tick - startTick : 1
        return max(1, min(sinceWindow, sincePlaced))
    }

    /// Raw count over the whole window.
    public func countInWindow(_ kind: Kind, _ item: ItemID, tick: UInt64, rules: GameRules) -> Int {
        guard let entry = entries.first(where: { $0.item == item }) else { return 0 }
        let current = tick / UInt64(rules.rateBucketTicks)
        let oldest = current >= UInt64(bucketIDs.count - 1) ? current - UInt64(bucketIDs.count - 1) : 0
        var total = 0
        for position in bucketIDs.indices where bucketIDs[position] != UInt64.max
            && bucketIDs[position] >= oldest && bucketIDs[position] <= current {
            switch kind {
            case .made: total += entry.made[position]
            case .used: total += entry.used[position]
            case .received: total += entry.received[position]
            }
        }
        return total
    }

    public var trackedItems: [ItemID] { entries.map(\.item) }

    private mutating func entryIndex(for item: ItemID) -> Int {
        if let index = entries.firstIndex(where: { $0.item == item }) { return index }
        let zeros = Array(repeating: 0, count: bucketIDs.count)
        let position = entries.firstIndex { $0.item > item } ?? entries.endIndex
        entries.insert(Entry(item: item, made: zeros, used: zeros, received: zeros), at: position)
        return position
    }
}
