/// Tuning numbers that are not tied to one recipe or building, from Data/rules.json.
public struct GameRules: Codable, Equatable, Sendable {
    /// Most items the player can carry at once, all of one kind.
    public var handCapacity: Int
    /// Discrete item slots on each belt tile.
    public var beltSlotsPerTile: Int
    /// Belt items move one slot every this many ticks.
    public var beltTicksPerSlot: Int
    /// Rates are counted in buckets of this many ticks...
    public var rateBucketTicks: Int
    /// ...and this many buckets make the rate window.
    public var rateBuckets: Int
    /// A machine must wait this long before it shows as blocked, so it does not
    /// flicker between crafts.
    public var blockGraceTicks: Int
    /// Most items a truck carries per trip.
    public var truckCapacity: Int
    /// A truck moves one road tile every this many ticks.
    public var truckTicksPerTile: Int
    /// A field's soil starts full at `soilMax`; below `soilTired` it grows at half speed.
    public var soilMax: Int
    public var soilTired: Int
    /// Rates, and the demand rule's "is supply steady?" check, look back this far.
    public var rateWindowTicks: Int { rateBucketTicks * rateBuckets }

    func problems() -> [String] {
        var problems: [String] = []
        let positive: [(String, Int)] = [
            ("handCapacity", handCapacity), ("beltSlotsPerTile", beltSlotsPerTile),
            ("beltTicksPerSlot", beltTicksPerSlot), ("rateBucketTicks", rateBucketTicks),
            ("rateBuckets", rateBuckets), ("truckCapacity", truckCapacity), ("truckTicksPerTile", truckTicksPerTile),
        ]
        for (name, value) in positive where value <= 0 {
            problems.append("Rule '\(name)' must be above 0")
        }
        if blockGraceTicks < 0 { problems.append("Rule 'blockGraceTicks' cannot be negative") }
        if beltSlotsPerTile < 2 { problems.append("Rule 'beltSlotsPerTile' must be at least 2") }
        return problems
    }
}
