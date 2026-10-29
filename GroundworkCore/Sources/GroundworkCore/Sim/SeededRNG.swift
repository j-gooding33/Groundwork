/// SplitMix64: a small, fast, seeded generator whose whole state is one number.
///
/// The simulation uses this and nothing else for randomness. Its state lives in
/// World, so a saved game resumes the exact same sequence.
public struct SplitMix64: RandomNumberGenerator, Codable, Equatable, Sendable {
    public private(set) var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// A value in `0..<bound`, without modulo bias.
    public mutating func nextInt(below bound: Int) -> Int {
        precondition(bound > 0, "bound must be positive")
        let limit = UInt64(bound)
        let threshold = (0 &- limit) % limit
        while true {
            let value = next()
            if value >= threshold { return Int(value % limit) }
        }
    }
}
