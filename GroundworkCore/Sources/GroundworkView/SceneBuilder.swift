import Foundation
import GroundworkCore

/// One thing to draw. The SpriteKit layer keeps one node per `id` and copies
/// these fields onto it each frame; the preview tool draws them to a PNG.
public struct Sprite: Equatable, Sendable {
    /// Stable identity, for reusing nodes between frames.
    public var id: String
    /// Atlas sprite name.
    public var name: String
    /// Centre of the sprite in scene points (y up).
    public var x: Double
    public var y: Double
    /// Draw order: higher is on top.
    public var z: Double
    public var flipX = false
    public var flipY = false
    public var alpha = 1.0
    /// Whole-number scale for overlays sized to a footprint (pixel art stays crisp).
    public var scale = 1.0
    public var tint = Tint.none
    /// Looping animation: the renderer cycles these names, `frameSeconds` each,
    /// starting `phase` seconds in. Empty means `name` alone.
    public var frames: [String] = []
    public var frameSeconds = 0.0
    public var phase = 0.0

    public init(id: String, name: String, x: Double, y: Double, z: Double) {
        self.id = id
        self.name = name
        self.x = x
        self.y = y
        self.z = z
    }

    /// The frame showing at a moment, for renderers without their own animation.
    public func frame(at seconds: Double) -> String {
        guard frames.count > 1, frameSeconds > 0 else { return name }
        let k = Int(((seconds + phase) / frameSeconds).rounded(.down))
        return frames[((k % frames.count) + frames.count) % frames.count]
    }
}

/// A few short lines of text under a building: its rates per minute.
public struct RateLabel: Equatable, Sendable {
    public var id: String
    /// Top centre of the label, in scene points.
    public var x: Double
    public var y: Double
    public var lines: [String]
    /// "logs out in 20s", shown in red.
    public var warning: String?
}

/// A name written on the map: a landmark such as "Clay" until the player has
/// used it, so a new player knows what the patches of colour are.
public struct MapLabel: Equatable, Sendable {
    public var id: String
    public var text: String
    /// Centre of the text, in scene points.
    public var x: Double
    public var y: Double
}

/// Layers, bottom to top. Things on the ground that stand up (buildings, trees,
/// people) share one layer sorted by how far down the screen they stand.
public enum Layer {
    public static let terrain = 0.0
    public static let edges = 1.0
    public static let belts = 2.0
    public static let items = 3.0
    public static let standing = 10.0
    /// The day-and-night wash sits here: everything below is tinted.
    public static let tint = 40.0
    /// Lit windows and fire, above the wash so they glow at night.
    public static let lights = 41.0
    /// Status bubbles over machines: above the night wash so they always show.
    public static let status = 45.0
    public static let overlay = 50.0
    public static let effects = 60.0
}

/// Moments the renderer needs beyond the world itself.
public struct RenderTime: Equatable, Sendable {
    /// How far into the next tick we are, from TickClock.fraction.
    public var fraction: Double
    /// Wall-clock seconds, for pulses and other animation that runs even when paused.
    public var seconds: Double

    public init(fraction: Double = 0, seconds: Double = 0) {
        self.fraction = fraction
        self.seconds = seconds
    }
}

/// Turns the world into sprites. Split in two so the app can rebuild the big
/// static layer (terrain, edges, trees) only when buildings or belts change.
public struct SceneBuilder: Sendable {
    public let content: ContentDatabase
    public let atlas: AtlasManifest

    public init(content: ContentDatabase, atlas: AtlasManifest) {
        self.content = content
        self.atlas = atlas
    }

    // MARK: Static layer

    /// Terrain, edge overlays, the paper margin, and trees, rocks and clay
    /// markers not covered by buildings or belts. Land the chapter hasn't
    /// drawn yet is blank paper, with the same soft edge as the map's margin.
    public func staticLayer(_ world: World) -> [Sprite] {
        let map = world.map
        var sprites: [Sprite] = []
        sprites.reserveCapacity(map.width * map.height * 2)
        for y in -2..<(map.height + 2) {
            for x in -2..<(map.width + 2) {
                let point = GridPoint(x, y)
                let c = Camera.center(of: point, w: 1, h: 1, mapHeight: map.height)
                guard let terrain = Self.drawnTerrain(at: point, world: world) else {
                    sprites.append(Sprite(id: "t:\(x),\(y)", name: "terrain_paper_fog", x: c.x, y: c.y, z: Layer.terrain))
                    continue
                }
                var base = Sprite(id: "t:\(x),\(y)", name: Self.baseSprite(terrain), x: c.x, y: c.y, z: Layer.terrain)
                if terrain == .water {
                    base.frames = atlas.frames("terrain_water")
                    base.frameSeconds = 0.6
                    base.phase = Double(Self.hash(point) % 3) * 0.6
                }
                sprites.append(base)
                for overlay in edgeOverlays(point, terrain: { Self.drawnTerrain(at: $0, world: world) }) {
                    sprites.append(Sprite(id: "e:\(x),\(y):\(overlay)", name: overlay, x: c.x, y: c.y, z: Layer.edges))
                }
                if let decoration = decoration(point, terrain: terrain, world: world) {
                    sprites.append(decoration)
                }
            }
        }
        return sprites
    }

    static func baseSprite(_ terrain: Terrain) -> String {
        switch terrain {
        case .grass, .rock: return "terrain_grass_1"
        case .grassLight: return "terrain_grass_2"
        case .grassDark, .forest: return "terrain_grass_3"
        case .water: return "terrain_water"
        case .shore: return "terrain_shore"
        case .dirt: return "terrain_dirt"
        case .clayGround: return "terrain_clay_ground"
        }
    }

    /// Terrain groups that spill over their lower neighbours, highest first wins
    /// the edge. Off the map counts as paper fog, above everything.
    static func edgeGroup(_ terrain: Terrain?) -> (name: String, priority: Int) {
        switch terrain {
        case nil: return ("fog", 5)
        case .water?: return ("water", 4)
        case .shore?: return ("shore", 3)
        case .clayGround?: return ("clay_ground", 2)
        case .dirt?: return ("dirt", 1)
        default: return ("grass", 0)
        }
    }

    /// The terrain to draw at a point: nil off the map or on undrawn paper.
    static func drawnTerrain(at point: GridPoint, world: World) -> Terrain? {
        world.isRevealed(point) ? world.map.terrain(at: point) : nil
    }

    /// Edge overlay sprites for a tile, lowest group first, sides then corners.
    public func edgeOverlays(_ point: GridPoint, map: TileMap) -> [String] {
        edgeOverlays(point, terrain: map.terrain(at:))
    }

    func edgeOverlays(_ point: GridPoint, terrain: (GridPoint) -> Terrain?) -> [String] {
        let own = Self.edgeGroup(terrain(point)).priority
        func group(_ dx: Int, _ dy: Int) -> (name: String, priority: Int) {
            Self.edgeGroup(terrain(GridPoint(point.x + dx, point.y + dy)))
        }
        let n = group(0, -1), s = group(0, 1), e = group(1, 0), w = group(-1, 0)
        let ne = group(1, -1), nw = group(-1, -1), se = group(1, 1), sw = group(-1, 1)
        let higher = Set([n, s, e, w, ne, nw, se, sw].filter { $0.priority > own }.map(\.priority))
        var overlays: [String] = []
        for priority in higher.sorted() {
            func on(_ g: (name: String, priority: Int)) -> Bool { g.priority == priority }
            let name = [n, s, e, w, ne, nw, se, sw].first { on($0) }!.name
            for (side, g) in [("n", n), ("e", e), ("s", s), ("w", w)] where on(g) {
                overlays.append("edge_\(name)_\(side)")
            }
            for (corner, g, a, b) in [("ne", ne, n, e), ("nw", nw, n, w), ("se", se, s, e), ("sw", sw, s, w)]
            where on(g) && !on(a) && !on(b) {
                overlays.append("edge_\(name)_\(corner)")
            }
        }
        return overlays.filter(atlas.has)
    }

    private func decoration(_ point: GridPoint, terrain: Terrain, world: World) -> Sprite? {
        guard world.building(at: point) == nil, world.belt(at: point) == nil else { return nil }
        let h = Self.hash(point)
        let base: String
        switch terrain {
        case .forest: base = "nature_tree"
        case .rock: base = "nature_rock"
        case .clayGround where h % 3 == 0 && world.map.deposit(at: point) != nil: base = "nature_clay_marker"
        default: return nil
        }
        let variants = atlas.variantCount(base)
        let name = h % UInt64(variants) == 0 ? base : "\(base)_v\(h % UInt64(variants))"
        let c = Camera.center(of: point, w: 1, h: 1, mapHeight: world.map.height)
        // A couple of pixels of jitter so a forest is not a grid of identical trees.
        let jx = Double(Int((h >> 8) % 5) - 2), jy = Double(Int((h >> 16) % 3) - 1)
        var sprite = Sprite(id: "d:\(point.x),\(point.y)", name: name, x: c.x + jx, y: c.y + jy,
                            z: standingZ(row: point.y, map: world.map))
        if terrain == .forest {
            sprite.frames = atlas.frames(name)
            sprite.frameSeconds = 1.1
            sprite.phase = Double(h % 7) * 0.3
        }
        return sprite
    }

    // MARK: Dynamic layer

    /// Buildings, belts, items on belts, villagers. Rebuild every frame.
    public func dynamicLayer(_ world: World, time: RenderTime) -> [Sprite] {
        var sprites: [Sprite] = []
        let dayNight = DayNight(tick: world.tick)
        for building in world.buildings {
            sprites += buildingSprites(building, world: world, night: dayNight.isNight, time: time)
        }
        sprites += beltSprites(world, time: time)
        sprites += Walkers.sprites(world: world, content: content, atlas: atlas, time: time)
        return sprites
    }

    func standingZ(row: Int, map: TileMap) -> Double {
        Layer.standing + Double(row) / Double(max(map.height, 1)) * 10
    }

    /// The sprite for a building, choosing stage, variant, night and animation.
    public func spriteName(for building: Building, night: Bool) -> String {
        guard let def = content.building(building.type) else { return building.type.rawValue }
        var name = building.type.rawValue
        if def.kind == .home && !building.isBuilt {
            return atlas.has("\(name)_scaffold") ? "\(name)_scaffold" : name
        }
        if def.kind == .construction && def.inputCapacity > 0 {
            let stage = min(4, building.input.total * 4 / def.inputCapacity)
            if stage > 0, atlas.has("\(name)_\(stage)") { return "\(name)_\(stage)" }
        }
        let variants = atlas.variantCount(name)
        let v = Int(building.id) % variants
        if v > 0 { name += "_v\(v)" }
        if night, atlas.has("\(name)_night") { name += "_night" }
        return name
    }

    private func buildingSprites(_ building: Building, world: World, night: Bool, time: RenderTime) -> [Sprite] {
        guard let def = content.building(building.type) else { return [] }
        let c = Camera.center(of: building.origin, w: def.width, h: def.height, mapHeight: world.map.height)
        let name = spriteName(for: building, night: night)
        var sprite = Sprite(id: "b:\(building.id)", name: name, x: c.x, y: c.y,
                            z: standingZ(row: building.origin.y + def.height - 1, map: world.map))
        switch building.status {
        case .running:
            let frames = atlas.frames(name)
            if frames.count > 1 {
                sprite.frames = frames
                sprite.frameSeconds = 0.18
            }
        case .blocked:
            // Dim, with an amber pulse: a stalled machine is itself a signal.
            sprite.alpha = 0.82
            let pulse = 0.5 + 0.5 * sin(time.seconds * 2 * .pi / 1.4)
            var amber = Tint.amber
            amber.amount *= pulse
            sprite.tint = amber
        default:
            break
        }
        var sprites = [sprite]
        sprites += statusSprites(building, def: def, center: c, world: world, time: time)
        // At night, the lit pixels go above the wash so windows and fire glow.
        let dayName = name.hasSuffix("_night") ? String(name.dropLast(6)) : name
        let glowing = def.kind == .home ? building.isBuilt
            : def.kind == .processor ? building.status == .running : true
        if night, glowing, atlas.has("\(dayName)_glow") {
            var glow = Sprite(id: "g:\(building.id)", name: "\(dayName)_glow", x: c.x, y: c.y, z: Layer.lights)
            let frames = atlas.frames("\(dayName)_glow")
            if frames.count > 1, building.status == .running {
                glow.frames = frames
                glow.frameSeconds = 0.18
            }
            sprites.append(glow)
        }
        // Chimney smoke from a working kiln and from every finished home.
        let smoking = (def.kind == .processor && building.status == .running && building.type == "brick_kiln")
            || (def.kind == .home && building.isBuilt)
        if smoking {
            let chimneyX = c.x + Double(def.width) * Camera.tile * 0.22
            let chimneyY = c.y + Double(def.height) * Camera.tile * 0.5
            let rise = (time.seconds + Double(building.id)).truncatingRemainder(dividingBy: 1.8) / 1.8
            var puff = Sprite(id: "s:\(building.id)", name: "fx_smoke_1", x: chimneyX + rise * 3, y: chimneyY + rise * 10,
                              z: Layer.effects)
            puff.frames = ["fx_smoke_1", "fx_smoke_2", "fx_smoke_3"].filter(atlas.has)
            puff.frameSeconds = 0.6
            puff.phase = Double(building.id) * 0.37
            puff.alpha = 1 - rise * 0.5
            sprites.append(puff)
        }
        return sprites
    }

    // MARK: Status bubbles

    /// What a machine's bubble shows, if anything: the item it is missing, or
    /// a glyph for a full output, a used-up source, or running slow.
    public func statusIcon(for building: Building, world: World) -> String? {
        guard let kind = content.building(building.type)?.kind, kind == .gatherer || kind == .processor else { return nil }
        switch building.status {
        case let .blocked(reason):
            switch reason {
            case let .missingInput(item), let .missingFuel(item): return "item_\(item)"
            case .outputFull: return "status_full"
            case .sourceDepleted, .noSource: return "status_empty"
            case .noPower: return nil
            }
        case .running where kind == .processor:
            return Trace.run(.building(building.id), world: world, content: content).root.state == .slow ? "status_slow" : nil
        default:
            return nil
        }
    }

    private func statusSprites(_ building: Building, def: BuildingDef, center c: ScenePoint, world: World,
                               time: RenderTime) -> [Sprite] {
        guard let icon = statusIcon(for: building, world: world), atlas.has(icon) else { return [] }
        let bob = (time.seconds * 2).truncatingRemainder(dividingBy: 2) < 1 ? 0.0 : 1.0
        let y = c.y + Double(def.height) * Camera.tile / 2 + 8 + bob
        return [Sprite(id: "st:\(building.id)", name: "ui_status_bubble", x: c.x, y: y, z: Layer.status),
                Sprite(id: "sti:\(building.id)", name: icon, x: c.x, y: y + 1, z: Layer.status + 0.5)]
    }

    // MARK: Rate labels

    /// Made and used per minute over each working building, plus a warning
    /// when an input will run out within a minute. Drawn when the rates view is on.
    public func rateLabels(_ world: World) -> [RateLabel] {
        var labels: [RateLabel] = []
        for building in world.buildings {
            guard let def = content.building(building.type),
                  [.gatherer, .processor, .yard].contains(def.kind) else { continue }
            var lines: [String] = []
            var warning: String?
            for rate in ItemRate.all(for: building, tick: world.tick, rules: content.rules) {
                let plural = content.plural(rate.item)
                if rate.made > 0 { lines.insert("+\(rate.made) \(plural)/min", at: 0) }
                if rate.used > 0 { lines.append("-\(rate.used) \(plural)") }
                if def.kind == .yard, rate.received > 0 { lines.append("\(rate.received) \(plural) in") }
                if let seconds = rate.runsOut(within: 60) { warning = "\(plural) out in \(seconds)s" }
            }
            guard !lines.isEmpty || warning != nil else { continue }
            let c = Camera.center(of: building.origin, w: def.width, h: def.height, mapHeight: world.map.height)
            labels.append(RateLabel(id: "rate:\(building.id)", x: c.x, y: c.y - Double(def.height) * Camera.tile / 2 - 2,
                                    lines: lines, warning: warning))
        }
        return Self.separate(labels)
    }

    // MARK: Map labels

    /// Landmark names on drawn land, each until its job is done: "Clay" until
    /// a pit is dug, "Lake" for the first chapter only.
    public func mapLabels(_ world: World) -> [MapLabel] {
        guard let state = world.level, let level = content.level(state.level) else { return [] }
        return level.landmarks.enumerated().compactMap { i, landmark in
            guard world.isRevealed(landmark.at) else { return nil }
            if let until = landmark.untilChapter, state.chapter >= until { return nil }
            if let type = landmark.hideWhenBuilt, world.buildings.contains(where: { $0.type == type }) { return nil }
            let c = Camera.center(of: landmark.at, w: 1, h: 1, mapHeight: world.map.height)
            return MapLabel(id: "landmark:\(i)", text: landmark.text, x: c.x, y: c.y)
        }
    }

    /// Scene points per character and per line of label text, roughly.
    public static let labelCharWidth = 4.0
    public static let labelLineHeight = 6.0

    /// Moves labels down until none overlap, top of the screen first, so two
    /// neighbouring buildings never print over each other.
    static func separate(_ labels: [RateLabel]) -> [RateLabel] {
        func box(_ l: RateLabel) -> (minX: Double, maxX: Double, top: Double, bottom: Double) {
            let chars = Double((l.lines + [l.warning ?? ""]).map(\.count).max() ?? 0)
            let rows = Double(l.lines.count + (l.warning == nil ? 0 : 1))
            return (l.x - chars * labelCharWidth / 2, l.x + chars * labelCharWidth / 2, l.y, l.y - rows * labelLineHeight)
        }
        var placed: [RateLabel] = []
        for var label in labels.sorted(by: { ($0.y, $1.x) > ($1.y, $0.x) }) {
            var moved = true
            while moved {
                moved = false
                let a = box(label)
                for other in placed {
                    let b = box(other)
                    if a.minX < b.maxX && b.minX < a.maxX && a.bottom < b.top && b.bottom < a.top {
                        label.y = b.bottom - 1
                        moved = true
                        break
                    }
                }
            }
            placed.append(label)
        }
        return placed.sorted { $0.id < $1.id }
    }

    // MARK: Belts and items

    /// Which way items enter a belt tile: from behind, or from one side when a
    /// belt turns into it. Nil when nothing feeds it.
    public static func entry(of tile: BeltTile, in world: World) -> Direction? {
        var side: Direction?
        for direction in Direction.allCases {
            guard let feeder = world.belt(at: tile.point.moved(direction)),
                  feeder.next == tile.point, feeder.direction != tile.direction.opposite else { continue }
            if feeder.direction == tile.direction { return tile.direction }
            if side == nil { side = feeder.direction }
        }
        return side
    }

    /// The sprite and flips for a belt tile.
    public static func beltPiece(_ tile: BeltTile, in world: World) -> (name: String, flipX: Bool, flipY: Bool) {
        let d = tile.direction
        if let entry = entry(of: tile, in: world), entry != d, tile.pullsFrom == nil {
            // Items arrive through the edge opposite their travel and leave through `d`.
            let edges = [entry.opposite, d]
            let vertical = edges.contains(.north) ? "n" : "s"
            let horizontal = edges.contains(.east) ? "e" : "w"
            return ("belt_\(vertical)\(horizontal)", false, false)
        }
        switch d {
        case .east: return ("belt_h", false, false)
        case .west: return ("belt_h", true, false)
        case .south: return ("belt_v", false, false)
        case .north: return ("belt_v", false, true)
        }
    }

    private func beltSprites(_ world: World, time: RenderTime) -> [Sprite] {
        let rules = content.rules
        let k = UInt64(rules.beltTicksPerSlot)
        // How far through the current slot-to-slot move we are, 0 to 1.
        let sub = (Double(world.tick % k) + time.fraction) / Double(k)
        let animFrame = Int(world.tick % 4)
        var sprites: [Sprite] = []
        for tile in world.belts.sorted(by: { $0.point < $1.point }) {
            let c = Camera.center(of: tile.point, w: 1, h: 1, mapHeight: world.map.height)
            let piece = Self.beltPiece(tile, in: world)
            var sprite = Sprite(id: "belt:\(tile.point.x),\(tile.point.y)", name: piece.name, x: c.x, y: c.y, z: Layer.belts)
            sprite.flipX = piece.flipX
            sprite.flipY = piece.flipY
            let frames = atlas.frames(piece.name)
            if frames.count > 1 { sprite.name = frames[animFrame % frames.count] }
            sprites.append(sprite)

            let entry = Self.entry(of: tile, in: world) ?? tile.direction
            let n = tile.slots.count
            for (s, item) in tile.slots.enumerated() {
                guard let item else { continue }
                let ahead = s + 1 < n ? tile.slots[s + 1] == nil : false
                var p = (Double(s) + 0.5) / Double(n)
                if ahead { p += sub / Double(n) }
                let pos = Self.pointAlong(tile: c, entry: entry, exit: tile.direction, progress: p)
                sprites.append(Sprite(id: "item:\(tile.point.x),\(tile.point.y):\(s)", name: "item_\(item)",
                                      x: pos.x, y: pos.y, z: Layer.items))
            }
        }
        return sprites
    }

    /// A point `progress` (0 to 1) of the way through a belt tile: from the edge
    /// items enter by, through the centre, out the edge they leave by.
    static func pointAlong(tile c: ScenePoint, entry: Direction, exit: Direction, progress p: Double) -> ScenePoint {
        func edgeMid(_ d: Direction) -> ScenePoint {
            let half = Camera.tile / 2
            switch d {
            case .north: return ScenePoint(c.x, c.y + half)
            case .south: return ScenePoint(c.x, c.y - half)
            case .east: return ScenePoint(c.x + half, c.y)
            case .west: return ScenePoint(c.x - half, c.y)
            }
        }
        let from = edgeMid(entry.opposite), to = edgeMid(exit)
        if p < 0.5 {
            let t = p / 0.5
            return ScenePoint(from.x + (c.x - from.x) * t, from.y + (c.y - from.y) * t)
        }
        let t = (p - 0.5) / 0.5
        return ScenePoint(c.x + (to.x - c.x) * t, c.y + (to.y - c.y) * t)
    }

    // MARK: Overlay

    /// The ghost belt while dragging, the tutorial's pulsing outline, and the
    /// gold dots along Trace lines.
    public func overlayLayer(_ world: World, input: InputController, hud: HUDModel, time: RenderTime) -> [Sprite] {
        var sprites: [Sprite] = []
        let mapHeight = world.map.height
        // Ghost belt: the same pieces the real belt would use, half see-through.
        for (k, point) in input.ghost.enumerated() {
            let c = Camera.center(of: point, w: 1, h: 1, mapHeight: mapHeight)
            let next = k + 1 < input.ghost.count ? input.ghost[k + 1] : nil
            let horizontal = next.map { $0.y == point.y } ?? (k > 0 && input.ghost[k - 1].y == point.y)
            var sprite = Sprite(id: "ghost:\(k)", name: horizontal ? "belt_h" : "belt_v", x: c.x, y: c.y,
                                z: Layer.overlay)
            sprite.alpha = 0.55
            sprites.append(sprite)
        }
        let pulse = 0.55 + 0.45 * sin(time.seconds * 2 * .pi / 1.1)
        if let bubble = hud.tutorial {
            if let tile = bubble.tile {
                let c = Camera.center(of: tile, w: 1, h: 1, mapHeight: mapHeight)
                var sprite = Sprite(id: "hl:tile", name: "ui_highlight", x: c.x, y: c.y, z: Layer.overlay + 1)
                sprite.alpha = pulse
                sprites.append(sprite)
            }
            for id in bubble.buildings {
                guard let b = world.building(id), let def = content.building(b.type) else { continue }
                let c = Camera.center(of: b.origin, w: def.width, h: def.height, mapHeight: mapHeight)
                var sprite = Sprite(id: "hl:\(id)", name: "ui_highlight", x: c.x, y: c.y, z: Layer.overlay + 1)
                sprite.scale = Double(max(def.width, def.height))
                sprite.alpha = pulse
                sprites.append(sprite)
            }
        }
        // A red marker bobbing over the step Trace says to fix.
        if let marker = hud.traceMarker {
            var dot = Sprite(id: "trace:marker", name: "ui_trace_dot", x: marker.x,
                             y: marker.y + 4 + 2 * sin(time.seconds * 2 * .pi / 0.8), z: Layer.overlay + 3)
            dot.tint = Tint(0.9, 0.15, 0.1, 0.85)
            dot.scale = 2
            sprites.append(dot)
        }
        // Dots travel along each Trace line, from supplier to consumer.
        for (n, line) in hud.traceLines.enumerated() {
            let dx = line.to.x - line.from.x, dy = line.to.y - line.from.y
            let length = (dx * dx + dy * dy).squareRoot()
            let count = max(2, Int(length / 10))
            for k in 0..<count {
                let t = (Double(k) + (time.seconds * 1.5).truncatingRemainder(dividingBy: 1)) / Double(count)
                var dot = Sprite(id: "trace:\(n):\(k)", name: "ui_trace_dot", x: line.from.x + dx * t,
                                 y: line.from.y + dy * t, z: Layer.overlay + 2)
                switch line.state {
                case .running: break
                case .slow: dot.tint = Tint(1, 0.6, 0.1, 0.7)
                case .blocked, .notBuilt: dot.tint = Tint(0.9, 0.15, 0.1, 0.85)
                }
                sprites.append(dot)
            }
        }
        return sprites
    }

    /// A stable pseudo-random number per tile, for visual variety only.
    static func hash(_ p: GridPoint) -> UInt64 {
        var z = UInt64(bitPattern: Int64(p.x &* 73_856_093 ^ p.y &* 19_349_663))
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
