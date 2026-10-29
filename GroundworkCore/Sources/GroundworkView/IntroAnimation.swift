/// The opening: ten builders, one per letter, lay bricks that spell
/// GROUNDWORK, then step back. Pure timing and layout, so it is tested here
/// and drawn by the app (and the preview) in whatever units it likes.
///
/// Positions are in brick cells: x grows right, y grows up from the ground.
public enum IntroAnimation {
    public static let word = "GROUNDWORK"
    /// Seconds until every brick is down.
    public static let layingSeconds = 1.5
    /// The whole intro, including the builders' little hop at the end.
    public static let duration = 1.8
    /// How long one brick takes to fly from a builder's hands to its place.
    public static let flightSeconds = 0.18

    public static let letterWidth = 5
    public static let letterHeight = 7
    public static let letterGap = 1
    /// Where the builders stand, in cells: just below the wall, so they never
    /// hide the letters.
    public static let builderGround = -2.4
    /// Total size of the word in cells.
    public static var width: Int { word.count * (letterWidth + letterGap) - letterGap }
    public static var height: Int { letterHeight }

    public struct Brick: Equatable, Sendable {
        public var letter: Int
        /// Where it ends up, in cells.
        public var cellX: Int
        public var cellY: Int
        /// Where it is now (mid-flight or in place), in cells.
        public var x: Double
        public var y: Double
        /// True once it has landed.
        public var placed: Bool
    }

    public struct Builder: Equatable, Sendable {
        public var letter: Int
        public var x: Double
        /// Height of the feet, in cells: `builderGround`, plus a hop at the end.
        public var y: Double
        /// "person_side_0", "person_side_1" or "person_front_0".
        public var sprite: String
        public var facingLeft: Bool
    }

    /// 5x7 letters, top row first.
    static let font: [Character: [String]] = [
        "G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".###."],
        "R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
        "O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
        "U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
        "N": ["#...#", "##..#", "#.#.#", "#.#.#", "#..##", "#...#", "#...#"],
        "D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
        "W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "##.##", "#...#"],
        "K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
    ]

    /// Each letter's bricks in the order they are laid: bottom row first,
    /// left to right, like a real wall.
    public static let plan: [[(x: Int, y: Int)]] = word.enumerated().map { i, ch in
        let rows = font[ch] ?? []
        var cells: [(x: Int, y: Int)] = []
        for (r, row) in rows.enumerated().reversed() {
            for (c, mark) in row.enumerated() where mark == "#" {
                cells.append((i * (letterWidth + letterGap) + c, letterHeight - 1 - r))
            }
        }
        return cells
    }

    /// When brick `k` of a letter with `count` bricks lands. Every letter
    /// finishes at `layingSeconds`, so the word completes all at once.
    static func landing(_ k: Int, of count: Int) -> Double {
        let start = flightSeconds
        return start + (layingSeconds - start) * Double(k + 1) / Double(max(count, 1))
    }

    public static func bricks(at t: Double) -> [Brick] {
        var out: [Brick] = []
        for (i, cells) in plan.enumerated() {
            let hands = handPosition(letter: i, at: t)
            for (k, cell) in cells.enumerated() {
                let land = landing(k, of: cells.count)
                let leave = land - flightSeconds
                guard t >= leave else { continue }
                if t >= land {
                    out.append(Brick(letter: i, cellX: cell.x, cellY: cell.y, x: Double(cell.x), y: Double(cell.y),
                                     placed: true))
                } else {
                    // A short arc from the builder's hands to the spot.
                    let p = (t - leave) / flightSeconds
                    let x = hands.x + (Double(cell.x) - hands.x) * p
                    let y = hands.y + (Double(cell.y) - hands.y) * p + 2 * p * (1 - p)
                    out.append(Brick(letter: i, cellX: cell.x, cellY: cell.y, x: x, y: y, placed: false))
                }
            }
        }
        return out
    }

    public static func builders(at t: Double) -> [Builder] {
        (0..<word.count).map { i in
            let x = builderX(letter: i, at: t)
            if t >= layingSeconds {
                // Done: face the player and hop once.
                let p = min(1, (t - layingSeconds) / (duration - layingSeconds))
                return Builder(letter: i, x: x, y: builderGround + 2.4 * p * (1 - p), sprite: "person_front_0",
                               facingLeft: false)
            }
            let step = Int(t * 12) % 2
            let target = nextCell(letter: i, at: t).map { Double($0.x) } ?? x
            return Builder(letter: i, x: x, y: builderGround, sprite: "person_side_\(step)", facingLeft: target < x)
        }
    }

    /// The builder walks under the brick it is about to lay.
    static func builderX(letter i: Int, at t: Double) -> Double {
        let left = Double(i * (letterWidth + letterGap))
        let center = left + Double(letterWidth - 1) / 2
        guard t < layingSeconds, let cell = nextCell(letter: i, at: t) else { return center }
        // Stand just beside the column, never more than a letter's width away.
        return min(max(Double(cell.x) - 0.5, left - 0.5), left + Double(letterWidth) - 0.5)
    }

    static func handPosition(letter i: Int, at t: Double) -> (x: Double, y: Double) {
        (builderX(letter: i, at: t), builderGround + 1.4)
    }

    /// The next brick this builder will throw (the first not yet in flight).
    static func nextCell(letter i: Int, at t: Double) -> (x: Int, y: Int)? {
        let cells = plan[i]
        for (k, cell) in cells.enumerated() where landing(k, of: cells.count) - flightSeconds > t {
            return cell
        }
        return cells.last
    }
}
