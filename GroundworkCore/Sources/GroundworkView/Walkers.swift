import GroundworkCore

/// Villagers strolling around their cottages. Decoration only: they are not
/// simulated, never touch the World, and follow a path worked out from the tick.
public enum Walkers {
    /// Tiles per second.
    static let speed = 1.1
    static let villagers = 6

    public static func sprites(world: World, content: ContentDatabase, atlas: AtlasManifest,
                               time: RenderTime) -> [Sprite] {
        let homes = world.buildings.filter { b in
            b.isBuilt && content.building(b.type)?.kind == .home
        }
        let seconds = (Double(world.tick) + time.fraction) / Double(Simulation.ticksPerSecond)
        var sprites: [Sprite] = []
        for (i, home) in homes.prefix(villagers * 2).enumerated() {
            guard let def = content.building(home.type) else { continue }
            let (point, facing) = position(around: home.origin, w: def.width, h: def.height,
                                           distance: seconds * speed + Double(i) * 2.7)
            let view: String, flip: Bool
            switch facing {
            case .east: (view, flip) = ("side", false)
            case .west: (view, flip) = ("side", true)
            case .north: (view, flip) = ("back", false)
            case .south: (view, flip) = ("front", false)
            }
            let frame = Int(seconds * 4) % 2
            let villager = i % villagers
            var name = "person_\(view)_\(frame)"
            if villager > 0 { name += "_v\(villager)" }
            guard atlas.has(name) else { continue }
            // Grid y grows south; scene y grows up. Feet sit a little below the tile centre.
            let x = (point.x + 0.5) * Camera.tile
            let y = (Double(world.map.height) - point.y - 0.5) * Camera.tile + 3
            var sprite = Sprite(id: "w:\(home.id)", name: name, x: x, y: y,
                                z: Layer.standing + (point.y + 0.6) / Double(max(world.map.height, 1)) * 10)
            sprite.flipX = flip
            sprites.append(sprite)
        }
        return sprites
    }

    /// A point on the loop one tile out from a footprint, `distance` tiles along
    /// it clockwise from the top-left corner, and which way the walker faces.
    static func position(around origin: GridPoint, w: Int, h: Int,
                         distance: Double) -> (point: (x: Double, y: Double), facing: Direction) {
        let left = Double(origin.x - 1), top = Double(origin.y - 1)
        let right = Double(origin.x + w), bottom = Double(origin.y + h)
        let width = right - left, height = bottom - top
        let loop = 2 * (width + height)
        var d = distance.truncatingRemainder(dividingBy: loop)
        if d < 0 { d += loop }
        if d < width { return ((left + d, top), .east) }
        d -= width
        if d < height { return ((right, top + d), .south) }
        d -= height
        if d < width { return ((right - d, bottom), .west) }
        d -= width
        return ((left, bottom - d), .north)
    }
}
