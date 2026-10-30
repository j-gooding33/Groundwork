import GroundworkCore

/// What the "New world" screen needs: turning typed seeds into numbers, a
/// small picture of the map before it is made, and a name to start with.
public enum NewWorld {
    /// A typed seed: a number is used as it is; any other text (a word, a
    /// phrase) is hashed, so "river town" always makes the same world.
    public static func seed(from text: String) -> UInt64 {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if let number = UInt64(trimmed) { return number }
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325       // FNV-1a
        for byte in trimmed.lowercased().utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return hash
    }

    /// A friendly default name, picked by the seed so it changes with the dice.
    public static func suggestedName(seed: UInt64) -> String {
        let first = ["Clay", "Willow", "Brick", "Mill", "Oak", "Kiln", "River", "Stone", "Ash", "Fern"]
        let second = ["Hollow", "Ford", "Field", "Green", "Bank", "Vale", "Hill", "Brook", "End", "Moor"]
        return "\(first[Int(seed % 10)]) \(second[Int((seed / 10) % 10)])"
    }

    public struct Preview: Equatable, Sendable {
        public var width: Int
        public var height: Int
        /// Row-major colours, one per tile.
        public var colors: [RGB]
        public var start: GridPoint
    }

    public struct RGB: Equatable, Sendable {
        public var r: Double, g: Double, b: Double
        init(_ hex: UInt32) {
            r = Double((hex >> 16) & 0xFF) / 255
            g = Double((hex >> 8) & 0xFF) / 255
            b = Double(hex & 0xFF) / 255
        }
    }

    /// The map these options would make, as one colour per tile.
    public static func preview(_ options: WorldOptions, content: ContentDatabase) -> Preview? {
        guard let def = content.worldGen else { return nil }
        let result = MapGenerator.generate(options, def: def, content: content)
        let map = result.map
        var colors: [RGB] = []
        colors.reserveCapacity(map.width * map.height)
        for y in 0..<map.height {
            for x in 0..<map.width {
                colors.append(color(map.terrain(at: GridPoint(x, y)) ?? .grass))
            }
        }
        return Preview(width: map.width, height: map.height, colors: colors, start: result.start)
    }

    /// Palette colours (Art/palette.json) for each kind of ground.
    static func color(_ terrain: Terrain) -> RGB {
        switch terrain {
        case .grass, .grassLight: return RGB(0x4A9A48)
        case .grassDark: return RGB(0x2F6B3A)
        case .water: return RGB(0x2C5AA0)
        case .shore: return RGB(0xC9A06B)
        case .dirt: return RGB(0x6B4A2F)
        case .clayGround: return RGB(0xB0583A)
        case .forest: return RGB(0x1E3A29)
        case .rock: return RGB(0xA3A3B0)
        }
    }
}
