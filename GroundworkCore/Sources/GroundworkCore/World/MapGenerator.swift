/// How much of a feature a new world has.
public enum Amount: String, Codable, CaseIterable, Sendable {
    case few, normal, lots
}

/// What the player chose for a new world. Saved with it.
public struct WorldOptions: Codable, Equatable, Sendable {
    public var name: String
    public var seed: UInt64
    public var water: Amount
    public var forest: Amount
    public var clay: Amount

    public init(name: String, seed: UInt64, water: Amount = .normal, forest: Amount = .normal, clay: Amount = .normal) {
        self.name = name
        self.seed = seed
        self.water = water
        self.forest = forest
        self.clay = clay
    }
}

/// Settings for generated worlds, from Data/worldgen.json.
public struct WorldGenDef: Codable, Equatable, Sendable {
    /// Per amount, out of 1000: how much of the map each feature covers, roughly.
    public struct Coverage: Codable, Equatable, Sendable {
        public var few: Int
        public var normal: Int
        public var lots: Int

        public func value(_ amount: Amount) -> Int {
            switch amount {
            case .few: return few
            case .normal: return normal
            case .lots: return lots
            }
        }
    }

    public var width: Int
    public var height: Int
    public var water: Coverage
    public var forest: Coverage
    public var clay: Coverage
    /// Out of 1000, for small rocky patches.
    public var rock: Int
    /// The start must have at least this many clay and forest tiles within `startRadius`.
    public var startRadius: Int
    public var startClay: Int
    public var startForest: Int
    /// Given to the first building of a type the player places, as in the tutorial.
    public var firstPlacementStock: [LevelDef.PlacementStock]
    /// Hints are offered for this long after a world begins (game ticks).
    public var hintTicks: Int
    /// A hint stays up at most this long if the player doesn't act on it.
    public var hintShowTicks: Int
}

/// Makes a new map from a seed. The same options always give the same map,
/// tile for tile. Integer maths only.
public enum MapGenerator {
    public struct Result: Equatable, Sendable {
        public var map: TileMap
        /// Flat land near the middle with clay and forest close by.
        public var start: GridPoint
    }

    public static func generate(_ options: WorldOptions, def: WorldGenDef, content: ContentDatabase) -> Result {
        let w = def.width, h = def.height
        // Independent noise fields per feature, each from its own stream of the seed.
        let waterNoise = Noise(seed: options.seed &+ 1, width: w, height: h)
        let forestNoise = Noise(seed: options.seed &+ 2, width: w, height: h)
        let clayNoise = Noise(seed: options.seed &+ 3, width: w, height: h)
        let rockNoise = Noise(seed: options.seed &+ 4, width: w, height: h)

        let waterCut = waterNoise.threshold(covering: def.water.value(options.water))
        let forestCut = forestNoise.threshold(covering: def.forest.value(options.forest))
        let clayCut = clayNoise.threshold(covering: def.clay.value(options.clay))
        let rockCut = rockNoise.threshold(covering: def.rock)

        var grid = [Character](repeating: ".", count: w * h)
        for y in 0..<h {
            for x in 0..<w {
                let i = y * w + x
                if waterNoise.values[i] >= waterCut { grid[i] = "~"; continue }
                if clayNoise.values[i] >= clayCut { grid[i] = "c"; continue }
                if forestNoise.values[i] >= forestCut { grid[i] = "T"; continue }
                let shade = hash(x, y, options.seed) % 10
                // Rocks are scattered through their patch, not packed solid.
                if rockNoise.values[i] >= rockCut, shade % 3 == 0 { grid[i] = "^"; continue }
                // Grass shades, for texture only.
                grid[i] = shade < 2 ? ":" : shade < 4 ? ";" : "."
            }
        }

        // A good place to start: land near the middle with clay and forest in reach.
        let center = GridPoint(w / 2, h / 2)
        func count(_ ch: Character, around p: GridPoint, _ r: Int) -> Int {
            var n = 0
            for y in max(0, p.y - r)...min(h - 1, p.y + r) {
                for x in max(0, p.x - r)...min(w - 1, p.x + r) where grid[y * w + x] == ch { n += 1 }
            }
            return n
        }
        var start = center
        var best = Int.max
        for y in stride(from: 8, to: h - 8, by: 2) {
            for x in stride(from: 8, to: w - 8, by: 2) {
                let p = GridPoint(x, y)
                let open = count(".", around: p, 3) + count(":", around: p, 3) + count(";", around: p, 3)
                guard open >= 30, count("c", around: p, def.startRadius) >= def.startClay,
                      count("T", around: p, def.startRadius) >= def.startForest,
                      count("~", around: p, 2) == 0 else { continue }
                let d = abs(x - center.x) + abs(y - center.y)
                if d < best { best = d; start = p }
            }
        }
        if best == Int.max {
            // Nowhere fits (few clay, few trees): make room in the middle.
            func blob(_ ch: Character, at p: GridPoint, _ r: Int) {
                for y in (p.y - r)...(p.y + r) {
                    for x in (p.x - r)...(p.x + r) where (x - p.x) * (x - p.x) + (y - p.y) * (y - p.y) <= r * r {
                        if x >= 0, y >= 0, x < w, y < h { grid[y * w + x] = ch }
                    }
                }
            }
            blob(".", at: center, 4)
            blob("c", at: GridPoint(center.x - 5, center.y + 1), 2)
            blob("T", at: GridPoint(center.x + 4, center.y - 6), 3)
            start = center
        }

        // Shore wherever land meets water.
        var final = grid
        for y in 0..<h {
            for x in 0..<w where grid[y * w + x] != "~" && grid[y * w + x] != "c" {
                let touches = [(0, 1), (0, -1), (1, 0), (-1, 0)].contains { dx, dy in
                    let nx = x + dx, ny = y + dy
                    return nx >= 0 && ny >= 0 && nx < w && ny < h && grid[ny * w + nx] == "~"
                }
                if touches { final[y * w + x] = "," }
            }
        }

        let text = (0..<h).map { y in String(final[(y * w)..<(y * w + w)]) }.joined(separator: "\n")
        // The generator only writes legend characters, so this cannot fail on valid content.
        let map = (try? TileMap.parse(text, content: content))
            ?? TileMap(width: w, height: h, terrain: Array(repeating: .grass, count: w * h))
        return Result(map: map, start: start)
    }

    static func hash(_ x: Int, _ y: Int, _ seed: UInt64) -> UInt64 {
        var rng = SplitMix64(seed: seed ^ (UInt64(truncatingIfNeeded: x) &* 0x9E37_79B9) ^ (UInt64(truncatingIfNeeded: y) << 32))
        return rng.next()
    }

    /// Smooth value noise, 0 to 1023 per tile: a coarse and a fine lattice of
    /// random values, blended with integer bilinear interpolation.
    struct Noise {
        let values: [Int]

        init(seed: UInt64, width: Int, height: Int) {
            var rng = SplitMix64(seed: seed)
            func lattice(_ step: Int) -> (Int, [Int]) {
                let cols = width / step + 2
                let rows = height / step + 2
                return (cols, (0..<(cols * rows)).map { _ in rng.nextInt(below: 1024) })
            }
            let octaves = [(step: 16, weight: 4), (step: 8, weight: 2), (step: 4, weight: 1)].map { octave in
                (octave.step, octave.weight, lattice(octave.step))
            }
            // Smoothstep easing, in integers: corners blend without straight seams.
            func ease(_ f: Int, _ step: Int) -> Int { f * f * (3 * step - 2 * f) / (step * step) }
            func sample(_ grid: [Int], cols: Int, step: Int, _ x: Int, _ y: Int) -> Int {
                let gx = x / step, gy = y / step
                let fx = ease(x % step, step), fy = ease(y % step, step)
                let a = grid[gy * cols + gx], b = grid[gy * cols + gx + 1]
                let c = grid[(gy + 1) * cols + gx], d = grid[(gy + 1) * cols + gx + 1]
                let top = a * (step - fx) + b * fx, bottom = c * (step - fx) + d * fx
                return (top * (step - fy) + bottom * fy) / (step * step)
            }
            let total = octaves.reduce(0) { $0 + $1.1 }
            var values: [Int] = []
            values.reserveCapacity(width * height)
            for y in 0..<height {
                for x in 0..<width {
                    var v = 0
                    for (step, weight, grid) in octaves {
                        v += weight * sample(grid.1, cols: grid.0, step: step, x, y)
                    }
                    values.append(v / total)
                }
            }
            self.values = values
        }

        /// The value below which `perMille` of tiles fall (for "low" features),
        /// or above which they rise, read from the other end with `1000 - perMille`.
        func threshold(covering perMille: Int) -> Int {
            let sorted = values.sorted()
            guard perMille > 0 else { return Int.max }
            let k = min(sorted.count - 1, sorted.count * (1000 - perMille) / 1000)
            return sorted[k]
        }
    }
}
