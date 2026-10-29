/// The fixed-tick simulation. Pure: the next world depends only on the current
/// world and the content, never on wall-clock time or frame rate.
public enum Simulation {
    public static let ticksPerSecond = 10

    /// Advances the world by exactly one tick.
    ///
    /// Later phases add stages here in a fixed order: commands, gatherers,
    /// belts, processors and construction, demand rule, rates, goals.
    public static func step(_ world: inout World, content: ContentDatabase) {
        world.tick += 1
    }
}
