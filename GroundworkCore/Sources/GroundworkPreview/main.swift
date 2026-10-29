// Renders screenshots of the real game without a Mac: plays levels through
// GameSession and InputController, draws SceneBuilder's sprites with the real
// atlas, and writes raw RGBA frames that Tools/preview.sh turns into PNGs.
//
// Usage: bash Tools/preview.sh   (writes docs/screenshots/*.png)
import Foundation
import GroundworkCore
import GroundworkView

setvbuf(stdout, nil, _IONBF, 0)

let root = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent()
let outDir = CommandLine.arguments.count > 1 ? URL(fileURLWithPath: CommandLine.arguments[1])
    : root.appendingPathComponent("docs/screenshots")
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let content = try ContentDatabase.load(from: root.appendingPathComponent("Data"))
let manifest = try AtlasManifest.load(from: root.appendingPathComponent("Art/generated/atlas.json"))
let atlasPixels = [UInt8](try Data(contentsOf: root.appendingPathComponent("Art/generated/atlas.rgba")))
let builder = SceneBuilder(content: content, atlas: manifest)

// MARK: Drawing

let scale = 2
let viewW = Int(Camera.viewWidth), viewH = Int(Camera.viewHeight)

struct Image {
    var w: Int, h: Int
    var px: [UInt8]
    init(w: Int, h: Int) {
        self.w = w
        self.h = h
        px = Array(repeating: 0, count: w * h * 4)
    }

    mutating func blend(_ x: Int, _ y: Int, _ r: Double, _ g: Double, _ b: Double, _ a: Double) {
        guard x >= 0, y >= 0, x < w, y < h, a > 0 else { return }
        let i = (y * w + x) * 4
        px[i] = UInt8(min(255, Double(px[i]) * (1 - a) + r * a))
        px[i + 1] = UInt8(min(255, Double(px[i + 1]) * (1 - a) + g * a))
        px[i + 2] = UInt8(min(255, Double(px[i + 2]) * (1 - a) + b * a))
        px[i + 3] = 255
    }
}

func draw(_ sprites: [Sprite], camera: Camera, seconds: Double, into image: inout Image) {
    let v = camera.visible
    for sprite in sprites.sorted(by: { ($0.z, $0.id) < ($1.z, $1.id) }) {
        let name = sprite.frame(at: seconds)
        guard let r = manifest.sprites[name] else { continue }
        // Sprite scale and camera zoom, both whole numbers for crisp pixels.
        let s = Int(sprite.scale) * max(1, Int(camera.zoom.rounded()))
        let w = r.w * s, h = r.h * s
        let left = Int(((sprite.x - v.minX) * camera.zoom).rounded()) - w / 2
        let top = Int(((v.maxY - sprite.y) * camera.zoom).rounded()) - h / 2
        if left > image.w || top > image.h || left + w < 0 || top + h < 0 { continue }
        for dy in 0..<h {
            for dx in 0..<w {
                var sx = dx / s, sy = dy / s
                if sprite.flipX { sx = r.w - 1 - sx }
                if sprite.flipY { sy = r.h - 1 - sy }
                let i = ((r.y + sy) * manifest.width + r.x + sx) * 4
                let a = Double(atlasPixels[i + 3]) / 255 * sprite.alpha
                guard a > 0 else { continue }
                var red = Double(atlasPixels[i]), green = Double(atlasPixels[i + 1]), blue = Double(atlasPixels[i + 2])
                let t = sprite.tint
                if t.amount > 0 {
                    red += (t.r * 255 - red) * t.amount
                    green += (t.g * 255 - green) * t.amount
                    blue += (t.b * 255 - blue) * t.amount
                }
                image.blend(left + dx, top + dy, red, green, blue, a)
            }
        }
    }
}

// A 3x5 pixel font for rate labels (the app uses a real font).
let glyphs: [Character: String] = [
    "a": "111101111101101", "b": "110101110101110", "c": "111100100100111", "d": "110101101101110",
    "e": "111100110100111", "f": "111100110100100", "g": "111100101101111", "h": "101101111101101",
    "i": "111010010010111", "j": "001001001101111", "k": "101101110101101", "l": "100100100100111",
    "m": "101111111101101", "n": "110101101101101", "o": "111101101101111", "p": "111101111100100",
    "q": "111101101111001", "r": "110101110101101", "s": "111100111001111", "t": "111010010010010",
    "u": "101101101101111", "v": "101101101101010", "w": "101101111111101", "x": "101101010101101",
    "y": "101101111010010", "z": "111001010100111", "0": "111101101101111", "1": "010110010010111",
    "2": "111001111100111", "3": "111001111001111", "4": "101101111001001", "5": "111100111001111",
    "6": "111100111101111", "7": "111001001001001", "8": "111101111101111", "9": "111101111001111",
    "+": "000010111010000", "-": "000000111000000", "/": "001001010100100", " ": "000000000000000",
]

func text(_ string: String, centerX: Int, top: Int, color: (Double, Double, Double), into image: inout Image) {
    let chars = Array(string.lowercased())
    var x = centerX - chars.count * 4 / 2
    for ch in chars {
        if let g = glyphs[ch] {
            for gy in 0..<5 {
                for gx in 0..<3 where g[g.index(g.startIndex, offsetBy: gy * 3 + gx)] == "1" {
                    // A dark outline pixel under each lit one keeps text readable on grass.
                    image.blend(x + gx + 1, top + gy + 1, 26, 28, 44, 0.8)
                    image.blend(x + gx, top + gy, color.0, color.1, color.2, 1)
                }
            }
        }
        x += 4
    }
}

func drawLabels(_ labels: [RateLabel], camera: Camera, into image: inout Image) {
    let v = camera.visible
    for label in labels {
        let cx = Int(((label.x - v.minX) * camera.zoom).rounded())
        var top = Int(((v.maxY - label.y) * camera.zoom).rounded()) + 1
        for line in label.lines {
            text(line, centerX: cx, top: top, color: (255, 244, 214), into: &image)
            top += 6
        }
        if let warning = label.warning {
            text(warning, centerX: cx, top: top, color: (255, 138, 61), into: &image)
        }
    }
}

func drawMapLabels(_ labels: [MapLabel], camera: Camera, into image: inout Image) {
    let v = camera.visible
    for label in labels {
        let cx = Int(((label.x - v.minX) * camera.zoom).rounded())
        let top = Int(((v.maxY - label.y) * camera.zoom).rounded()) - 2
        text(label.text, centerX: cx, top: top, color: (255, 244, 214), into: &image)
    }
}

func shot(_ name: String, session: GameSession, camera: Camera, input: InputController = InputController(),
          fraction: Double = 0.5, seconds: Double = 0.3) throws {
    let world = session.world
    let hud = HUDModel(session: session, input: input)
    let time = RenderTime(fraction: fraction, seconds: seconds)
    var image = Image(w: viewW, h: viewH)
    let dynamic = builder.dynamicLayer(world, time: time)
    draw(builder.staticLayer(world), camera: camera, seconds: seconds, into: &image)
    draw(dynamic.filter { $0.z < Layer.tint }, camera: camera, seconds: seconds, into: &image)
    // Day and night: multiply everything below the tint layer.
    let m = DayNight(tick: world.tick).tint.multiplier
    for i in stride(from: 0, to: image.px.count, by: 4) {
        image.px[i] = UInt8(Double(image.px[i]) * m.r)
        image.px[i + 1] = UInt8(Double(image.px[i + 1]) * m.g)
        image.px[i + 2] = UInt8(Double(image.px[i + 2]) * m.b)
    }
    draw(dynamic.filter { $0.z >= Layer.tint }, camera: camera, seconds: seconds, into: &image)
    draw(builder.overlayLayer(world, input: input, hud: hud, time: time), camera: camera, seconds: seconds, into: &image)
    if input.showRates { drawLabels(builder.rateLabels(world), camera: camera, into: &image) }
    drawMapLabels(builder.mapLabels(world), camera: camera, into: &image)

    var scaled = [UInt8](repeating: 0, count: viewW * scale * viewH * scale * 4)
    for y in 0..<(viewH * scale) {
        for x in 0..<(viewW * scale) {
            let s = ((y / scale) * viewW + x / scale) * 4, d = (y * viewW * scale + x) * 4
            scaled[d..<d + 4] = image.px[s..<s + 4]
        }
    }
    let file = outDir.appendingPathComponent("\(name)_\(viewW * scale)x\(viewH * scale).rgba")
    try Data(scaled).write(to: file)
    let goal = session.goal.map { "\($0.current)/\($0.target)" } ?? "-"
    print("\(name): tick \(world.tick), \(DayNight(tick: world.tick).clockText), goal \(goal), "
          + "step \(session.tutorialStep?.id ?? "done"), hud: \(hud.tutorial?.text.replacingOccurrences(of: "\n", with: " ") ?? "")")
}

func waitUntil(_ session: GameSession, limit: Int = 6000, _ condition: () -> Bool) {
    var n = 0
    while !condition() && n < limit {
        session.advance(ticks: 1)
        n += 1
    }
    if !condition() { print("warning: timed out at tick \(session.world.tick)") }
}

func check(_ feedback: Feedback, _ what: String) {
    if let toast = feedback.toast { print("  \(what): \(toast)") }
}

// MARK: Level 1, played through the input controller

let level1 = try GameSession(content: content)
var input = InputController()
var camera = Camera(mapWidth: level1.world.map.width, mapHeight: level1.world.map.height,
                    focus: level1.level?.focus, zoom: 1)
try shot("01_opening", session: level1, camera: camera, input: input)

input.use(.build("clay_pit"))
check(input.tap(level1.tutorialStep!.highlight!.tile!, session: level1), "place pit")
waitUntil(level1) { level1.tutorialStep?.id == "l1_kiln" }
input.use(.build("brick_kiln"))
let kilnTile = level1.tutorialStep!.highlight!.tile!
check(input.tap(kilnTile, session: level1), "place kiln")
input.cancel()
let pit = level1.world.buildings.first { $0.type == "clay_pit" }!
let kiln = level1.world.buildings.first { $0.type == "brick_kiln" }!
waitUntil(level1) { (level1.world.building(pit.id)?.output.count(of: "clay") ?? 0) >= 2 }
check(input.tap(pit.origin, session: level1), "pick up clay")
check(input.tap(kiln.origin, session: level1), "drop clay")
waitUntil(level1) { level1.tutorialStep?.id == "l1_belt" }
input.use(.belt)
input.dragBegan(pit.origin, session: level1)
input.dragMoved(kiln.origin, session: level1)
try shot("02_dragging_belt", session: level1, camera: camera, input: input)
check(input.dragEnded(kiln.origin, session: level1), "lay belt")
level1.advance(ticks: 120)
try shot("03_first_belt", session: level1, camera: camera, input: input)

input.use(.belt)
let foundation = level1.world.buildings.first { $0.type == "foundation" }!
input.dragBegan(kiln.origin, session: level1)
check(input.dragEnded(foundation.origin, session: level1), "belt to foundation")
waitUntil(level1) { level1.tutorialStep?.id == "l1_logs" }
try shot("04_tutorial_asks_for_trace", session: level1, camera: camera, input: input, seconds: 0.3)
input.use(.trace)
check(input.tap(kiln.origin, session: level1), "trace kiln")
try shot("05_trace_shows_the_gap", session: level1, camera: camera, input: input, seconds: 0.9)

input.use(.build("lumber_camp"))
let forest = level1.tutorialStep!.highlight!.tile!
check(input.tap(forest, session: level1), "place lumber camp")
input.use(.belt)
input.dragBegan(forest, session: level1)
check(input.dragEnded(kiln.origin, session: level1), "belt logs to kiln")
input.cancel()
waitUntil(level1) { level1.isGoalReached }
level1.advance(ticks: 40)
try shot("06_chapter1_complete", session: level1, camera: camera, input: input)

// Continue: the next chapter draws more of the map and a crate appears.
level1.beginNextChapter()
let wide = Camera(mapWidth: level1.world.map.width, mapHeight: level1.world.map.height,
                  focus: level1.level?.revealCenter, zoom: 1)
try shot("06b_chapter2_more_land", session: level1, camera: wide, input: InputController())

// MARK: Chapter 3, a small town building itself

let town = try GameSession(content: content, seed: 3, chapter: 2)
var townInput = InputController()
func place(_ type: BuildingTypeID, _ x: Int, _ y: Int) {
    townInput.use(.build(type))
    check(townInput.tap(GridPoint(x, y), session: town), "place \(type)")
}
func belt(_ a: (Int, Int), _ b: (Int, Int)) {
    townInput.use(.belt)
    townInput.dragBegan(GridPoint(a.0, a.1), session: town)
    check(townInput.dragEnded(GridPoint(b.0, b.1), session: town), "belt \(a) to \(b)")
}
place("clay_pit", 36, 30)
place("clay_pit", 37, 31)
place("lumber_camp", 42, 23)
place("lumber_camp", 44, 23)
place("brick_kiln", 41, 28)        // a 2x2 tap centres on the tile
place("sawmill", 47, 25)
place("builders_yard", 51, 28)
belt((36, 30), (41, 28))
belt((37, 31), (41, 28))
belt((42, 23), (41, 28))
belt((44, 23), (47, 25))
belt((41, 28), (51, 28))
belt((47, 25), (51, 28))
townInput.cancel()
town.advance(ticks: 3600)
var ratesInput = townInput
ratesInput.toggleRates()
let ratesCamera = Camera(mapWidth: town.world.map.width, mapHeight: town.world.map.height,
                         focus: GridPoint(44, 27), zoom: 1)
try shot("07_rates_view", session: town, camera: ratesCamera, input: ratesInput)
town.advance(ticks: 3600)
var townCamera = Camera(mapWidth: town.world.map.width, mapHeight: town.world.map.height,
                        focus: GridPoint(46, 28), zoom: 1)
try shot("08_town_day", session: town, camera: townCamera, input: townInput)
town.advance(ticks: 2100)
try shot("09_town_night", session: town, camera: townCamera, input: townInput)
townCamera.pinch(2, aroundView: ScenePoint(Camera.viewWidth / 2, Camera.viewHeight / 2))
try shot("10_town_zoomed", session: town, camera: townCamera, input: townInput)
town.advance(ticks: 3000)
try shot("11_town_stalls", session: town, camera: townCamera, input: townInput)
let homes = town.world.buildings.filter { $0.type == "cottage" }
print("Town: \(homes.filter(\.isBuilt).count) cottages built, \(homes.count - homes.filter(\.isBuilt).count) underway")
