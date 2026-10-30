import XCTest
@testable import GroundworkCore

final class NewWorldTests: XCTestCase {
    private func world(_ seed: UInt64, water: Amount = .normal, forest: Amount = .normal,
                       clay: Amount = .normal) throws -> GameSession {
        try GameSession.newWorld(content: try TestSupport.content(),
                                 options: WorldOptions(name: "Test", seed: seed, water: water, forest: forest, clay: clay))
    }

    private func count(_ terrain: Terrain, in map: TileMap) -> Int { map.terrain.filter { $0 == terrain }.count }

    func testTheSameSeedMakesTheSameWorld() throws {
        let a = try world(42), b = try world(42), c = try world(43)
        XCTAssertEqual(a.world.map, b.world.map)
        XCTAssertNotEqual(a.world.map, c.world.map)
        XCTAssertEqual(try a.save(), try b.save())
    }

    func testChoicesChangeTheLand() throws {
        let dry = try world(7, water: .few), wet = try world(7, water: .lots)
        XCTAssertLessThan(count(.water, in: dry.world.map), count(.water, in: wet.world.map))
        let bare = try world(7, forest: .few), wooded = try world(7, forest: .lots)
        XCTAssertLessThan(count(.forest, in: bare.world.map), count(.forest, in: wooded.world.map))
    }

    func testEveryWorldStartsNearClayAndForest() throws {
        for seed in UInt64(1)...12 {
            for amount in Amount.allCases {
                let session = try world(seed, water: .lots, forest: amount, clay: amount)
                let start = try XCTUnwrap(session.startPoint)
                let near = session.world.map.deposits.filter {
                    abs($0.point.x - start.x) <= 12 && abs($0.point.y - start.y) <= 12
                }
                XCTAssertTrue(near.contains { $0.source == "clay_deposit" }, "seed \(seed) \(amount): clay near the start")
                XCTAssertTrue(near.contains { $0.source == "forest" }, "seed \(seed) \(amount): forest near the start")
                XCTAssertNotEqual(session.world.map.terrain(at: start), .water)
            }
        }
    }

    func testANewWorldIsOpenAndRemembersItsName() throws {
        let session = try world(5)
        XCTAssertNil(session.world.unlocked, "Every building")
        XCTAssertNil(session.world.beltsAvailable, "No belt limit")
        XCTAssertNil(session.goal)
        XCTAssertNil(session.tutorialStep)
        let loaded = try GameSession.load(try session.save(), content: session.content)
        XCTAssertEqual(loaded.world.options?.name, "Test")
        XCTAssertEqual(loaded.world.options?.seed, 5)
    }

    func testHintsFollowWhatThePlayerDoes() throws {
        let session = try world(11)
        XCTAssertEqual(session.hint?.id, "h_clay", "The first hint shows straight away")
        let clay = try XCTUnwrap(session.world.map.deposits.first { d in
            d.source == "clay_deposit" && abs(d.point.x - session.startPoint!.x) <= 12
                && abs(d.point.y - session.startPoint!.y) <= 12
        })
        XCTAssertEqual(session.place("clay_pit", at: clay.point), .ok)
        XCTAssertEqual(session.hint?.id, "h_kiln", "Placing the pit moves on to the next hint")
        session.dismissHint()
        XCTAssertNil(session.hint)
        session.advance(ticks: 1)
        XCTAssertNotEqual(session.hint?.id, "h_kiln", "A dismissed hint does not come back")
    }

    func testHintsStopAfterTheFirstHour() throws {
        let session = try world(12)
        let window = try XCTUnwrap(session.content.worldGen).hintTicks
        session.advance(ticks: window + 1)
        XCTAssertNil(session.hint)
        session.place("lumber_camp", at: try XCTUnwrap(session.world.map.deposits.first { $0.source == "forest" }).point)
        session.advance(ticks: 10)
        XCTAssertNil(session.hint, "No new hints once the first hour is over")
    }

    func testTheFirstKilnGetsStartingLogs() throws {
        let session = try world(13)
        let start = try XCTUnwrap(session.startPoint)
        var spot: GridPoint?
        search: for r in 0...10 {
            for dy in -r...r { for dx in -r...r {
                let p = GridPoint(start.x + dx, start.y + dy)
                if session.place("brick_kiln", at: p) == .ok { spot = p; break search }
            } }
        }
        let kiln = try XCTUnwrap(session.world.buildings.first { $0.type == "brick_kiln" }, "placed at \(String(describing: spot))")
        XCTAssertEqual(kiln.input.count(of: "log"), 5)
    }
}
