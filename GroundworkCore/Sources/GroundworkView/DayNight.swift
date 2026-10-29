import GroundworkCore

/// A colour wash over the world, 0 to 1 per channel.
public struct Tint: Equatable, Sendable {
    public var r: Double
    public var g: Double
    public var b: Double
    /// How strongly to apply it, 0 (none) to 1.
    public var amount: Double

    public init(_ r: Double, _ g: Double, _ b: Double, _ amount: Double) {
        self.r = r
        self.g = g
        self.b = b
        self.amount = amount
    }

    public static let none = Tint(1, 1, 1, 0)

    /// The colour to multiply the world by (SpriteKit: a full-screen node with
    /// `.multiply` blending). White when `amount` is 0.
    public var multiplier: (r: Double, g: Double, b: Double) {
        (1 - amount + amount * r, 1 - amount + amount * g, 1 - amount + amount * b)
    }
    /// Blocked machines pulse with this.
    public static let amber = Tint(1.0, 0.62, 0.15, 0.45)
}

/// Light follows the time of day: warm dawn, flat midday, orange dusk, night.
/// Purely a rendering choice: it reads the tick and never changes the world.
public struct DayNight: Equatable, Sendable {
    /// One day lasts 10 minutes of game time.
    public static let dayTicks: UInt64 = 6000
    /// Games start mid-morning.
    public static let startPhase = 0.32

    /// 0 is midnight, 0.5 is noon.
    public let phase: Double
    public let day: Int

    public init(tick: UInt64) {
        let total = Double(tick) / Double(Self.dayTicks) + Self.startPhase
        day = Int(total) + 1
        phase = total - Double(Int(total))
    }

    public var isNight: Bool { phase < 0.21 || phase > 0.8 }

    /// "Day 1, 07:40"
    public var clockText: String {
        let minutes = Int(phase * 24 * 60)
        let h = minutes / 60, m = minutes % 60
        return "Day \(day), \(h < 10 ? "0" : "")\(h):\(m < 10 ? "0" : "")\(m)"
    }

    /// The wash over the world, eased between key moments of the day.
    public var tint: Tint {
        let keys: [(Double, Tint)] = [
            (0.00, Tint(0.18, 0.22, 0.48, 0.55)),
            (0.20, Tint(0.18, 0.22, 0.48, 0.50)),
            (0.25, Tint(1.00, 0.62, 0.38, 0.28)),   // dawn
            (0.32, Tint(1.00, 0.90, 0.75, 0.06)),
            (0.40, .none),
            (0.66, .none),
            (0.74, Tint(1.00, 0.52, 0.22, 0.30)),   // dusk
            (0.80, Tint(0.30, 0.25, 0.50, 0.45)),
            (1.00, Tint(0.18, 0.22, 0.48, 0.55)),
        ]
        for k in 1..<keys.count where phase <= keys[k].0 {
            let (p0, a) = keys[k - 1], (p1, b) = keys[k]
            let t = (phase - p0) / (p1 - p0)
            return Tint(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t,
                        a.amount + (b.amount - a.amount) * t)
        }
        return keys[0].1
    }
}
