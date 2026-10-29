/// Turns frame time into whole simulation ticks.
///
/// The renderer calls `ticks(forElapsed:)` once per frame and passes the result
/// to `GameSession.advance(ticks:)`. Leftover time carries to the next frame, so
/// the simulation keeps 10 ticks per second whatever the frame rate. Floating
/// point stays here and never reaches World.
public struct TickClock: Sendable {
    /// 1 is normal speed; 2 and 4 are fast-forward. 0 pauses.
    public var speed: Int
    /// Ticks allowed in one frame, so a long stall cannot freeze the app catching up.
    public var maxTicksPerFrame: Int
    private var carriedSeconds: Double = 0

    public init(speed: Int = 1, maxTicksPerFrame: Int = 40) {
        self.speed = speed
        self.maxTicksPerFrame = maxTicksPerFrame
    }

    /// How far the next tick has progressed, from 0 up to 1. The renderer uses
    /// this to glide belt items between slots instead of jumping 10 times a
    /// second. It never feeds back into the simulation.
    public var fraction: Double {
        min(1, carriedSeconds * Double(Simulation.ticksPerSecond))
    }

    public mutating func ticks(forElapsed seconds: Double) -> Int {
        guard speed > 0, seconds > 0 else { return 0 }
        carriedSeconds += seconds * Double(speed)
        let tickLength = 1.0 / Double(Simulation.ticksPerSecond)
        // The small epsilon stops 0.1 + 0.1 + 0.1 landing just under 3 ticks.
        let whole = Int((carriedSeconds / tickLength) + 1e-9)
        let ticks = min(whole, maxTicksPerFrame)
        carriedSeconds = whole > maxTicksPerFrame ? 0 : max(0, carriedSeconds - Double(ticks) * tickLength)
        return ticks
    }
}
