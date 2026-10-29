/// Everything that exists in a game, as one Codable value.
///
/// Saving a game is encoding this; loading is decoding it. The simulation
/// changes it only through `Simulation.step`, and only on whole ticks.
public struct World: Codable, Equatable, Sendable {
    public internal(set) var tick: UInt64
    public internal(set) var rng: SplitMix64
    public internal(set) var map: TileMap
    public internal(set) var nextEntityID: UInt32

    public init(map: TileMap, seed: UInt64) {
        tick = 0
        rng = SplitMix64(seed: seed)
        self.map = map
        nextEntityID = 1
    }
}
