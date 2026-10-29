import Foundation

/// The one entry point a renderer or UI uses. It owns the world and the
/// content, advances the simulation, and saves and loads.
///
/// Commands, Trace, events and undo arrive in later phases (see docs/PLAN.md).
public final class GameSession {
    public let content: ContentDatabase
    public private(set) var world: World

    public init(content: ContentDatabase, map: TileMap, seed: UInt64) {
        self.content = content
        world = World(map: map, seed: seed)
    }

    private init(content: ContentDatabase, world: World) {
        self.content = content
        self.world = world
    }

    /// Runs whole ticks. Fast-forward calls this with more ticks per frame.
    public func advance(ticks: Int) {
        precondition(ticks >= 0, "Cannot advance by a negative number of ticks")
        for _ in 0..<ticks {
            Simulation.step(&world, content: content)
        }
    }

    /// The world as JSON. Keys are sorted, so the same world always gives the same bytes.
    public func save() throws -> Data {
        try Self.encoder.encode(world)
    }

    public static func load(_ data: Data, content: ContentDatabase) throws -> GameSession {
        GameSession(content: content, world: try JSONDecoder().decode(World.self, from: data))
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()
}
