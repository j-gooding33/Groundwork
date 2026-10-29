import XCTest
@testable import GroundworkCore

final class BeltTests: XCTestCase {
    private let open = [
        "............",
        ".c..........",
        "............",
        "............",
        "............",
        "............",
    ]

    private func turns(_ points: [GridPoint]) -> Int {
        guard points.count > 2 else { return 0 }
        var count = 0
        for k in 2..<points.count {
            let a = (points[k - 1].x - points[k - 2].x, points[k - 1].y - points[k - 2].y)
            let b = (points[k].x - points[k - 1].x, points[k].y - points[k - 1].y)
            if a != b { count += 1 }
        }
        return count
    }

    /// A raw world with a crate at the east end of a straight line of belt.
    private func lineIntoCrate(length: Int, items: [ItemID?]) throws -> (World, ContentDatabase, EntityID) {
        let content = try TestSupport.content()
        let map = try TileMap.parse(String(repeating: ".", count: length + 2), content: content)
        var world = World(map: map, seed: 1)
        let crate = Commands.insertBuilding("storage_crate", at: GridPoint(length, 0), facing: .south,
                                            world: &world, content: content)
        let slots = content.rules.beltSlotsPerTile
        for x in 0..<length {
            var tile = BeltTile(point: GridPoint(x, 0), direction: .east, slots: slots, pullsFrom: nil)
            for s in 0..<slots {
                let k = x * slots + s
                if k < items.count { tile.slots[s] = items[k] }
            }
            world.belts.append(tile)
        }
        BeltSystem.reorder(&world, content: content)
        return (world, content, crate)
    }

    func testBeltFromPitToKilnDeliversClay() throws {
        let session = try TestSupport.session(open)
        let pit = try TestSupport.place("clay_pit", at: GridPoint(1, 1), in: session)
        let kiln = try TestSupport.place("brick_kiln", at: GridPoint(8, 1), in: session)
        XCTAssertEqual(session.layBelt(from: GridPoint(1, 1), to: GridPoint(8, 1)), .ok)

        let belts = session.world.belts.sorted { $0.point.x < $1.point.x }
        XCTAssertEqual(belts.first?.pullsFrom, pit)
        let kilnDef = try XCTUnwrap(session.content.building("brick_kiln"))
        let kilnBuilding = try XCTUnwrap(session.world.building(kiln))
        XCTAssertTrue(session.world.belts.contains { kilnBuilding.covers($0.next, kilnDef) },
                      "The last tile points into the kiln")
        XCTAssertEqual(belts.count, 6, "Straight run between the pit and the kiln")

        session.advance(ticks: 200)
        XCTAssertGreaterThan(session.rates(of: kiln).first { $0.item == "clay" }?.received ?? 0, 0)
        XCTAssertTrue(session.drainEvents().contains(.itemDelivered(kiln, "clay", via: .belt)))
    }

    func testItemsArriveInOrder() throws {
        let line: [ItemID?] = ["clay", nil, "log", "brick", nil, nil, "plank", "clay", "log", nil, "brick"]
        var (world, content, crate) = try lineIntoCrate(length: 3, items: line)
        var events: [GameEvent] = []
        for _ in 0..<100 { Simulation.step(&world, content: content, events: &events) }
        let delivered = events.compactMap { event -> ItemID? in
            if case let .itemDelivered(id, item, _) = event, id == crate { return item }
            return nil
        }
        // The exit end is the highest slot of the easternmost tile, so the line reads back to front.
        XCTAssertEqual(delivered, Array(line.compactMap { $0 }.reversed()))
    }

    func testItemsAreNeverLostOrDuplicated() throws {
        let session = try TestSupport.session(open)
        let pit = try TestSupport.place("clay_pit", at: GridPoint(1, 1), in: session)
        let crate = try TestSupport.place("storage_crate", at: GridPoint(10, 4), in: session)
        XCTAssertEqual(session.layBelt(from: GridPoint(1, 1), to: GridPoint(10, 4)), .ok)
        for tick in 0..<10_000 {
            session.advance(ticks: 1)
            let world = session.world
            let taken = 200 - (world.map.deposit(at: GridPoint(1, 1))?.remaining ?? 0)
            let pitBuilding = try XCTUnwrap(world.building(pit))
            let onBelts = world.belts.reduce(0) { $0 + $1.items.count }
            let inCrate = world.building(crate)?.input.count(of: "clay") ?? 0
            let crafting = pitBuilding.progress > 0 ? 1 : 0
            let accounted = pitBuilding.output.count(of: "clay") + onBelts + inCrate + crafting
            if taken != accounted {
                return XCTFail("Tick \(tick): took \(taken) clay from the ground but can find \(accounted)")
            }
        }
        XCTAssertEqual(session.world.building(crate)?.input.count(of: "clay"), 50, "The crate fills up")
    }

    func testRouteGoesAroundWater() throws {
        let session = try TestSupport.session([
            "..........",
            "....~.....",
            "....~.....",
            "....~.....",
            "..........",
        ])
        let preview = try XCTUnwrap(session.previewBelt(from: GridPoint(1, 2), to: GridPoint(8, 2)))
        XCTAssertTrue(preview.allSatisfy { session.world.map.terrain(at: $0) != .water })
        XCTAssertEqual(preview.first, GridPoint(1, 2))
        XCTAssertEqual(preview.last, GridPoint(8, 2))
        XCTAssertEqual(session.layBelt(from: GridPoint(1, 2), to: GridPoint(8, 2)), .ok)
        XCTAssertEqual(Set(session.world.belts.map(\.point)), Set(preview))

        let again = try TestSupport.session([
            "..........", "....~.....", "....~.....", "....~.....", "..........",
        ])
        XCTAssertEqual(again.previewBelt(from: GridPoint(1, 2), to: GridPoint(8, 2)), preview, "Same drag, same belt")
    }

    func testRoutePrefersStraightRuns() throws {
        let session = try TestSupport.session(open)
        let path = try XCTUnwrap(session.previewBelt(from: GridPoint(0, 0), to: GridPoint(9, 5)))
        XCTAssertEqual(path.count, 15, "Shortest length: 9 across + 5 down + the start tile")
        XCTAssertEqual(turns(path), 1, "One corner, not a staircase")
    }

    func testNoRouteThroughAWall() throws {
        let session = try TestSupport.session(["..~..", "..~..", "..~.."])
        guard case .rejected(.noRoute) = session.layBelt(from: GridPoint(0, 1), to: GridPoint(4, 1)) else {
            return XCTFail("Water cuts the map in two")
        }
    }

    func testSideLoadMergesIntoALine() throws {
        let session = try TestSupport.session([
            "............",
            "............",
            "............",
            "............",
            "............",
        ])
        let a = try TestSupport.place("storage_crate", at: GridPoint(0, 3), in: session)
        let b = try TestSupport.place("storage_crate", at: GridPoint(5, 0), in: session)
        let end = try TestSupport.place("storage_crate", at: GridPoint(11, 3), in: session)
        session.stock(a, with: "clay", count: 5)
        session.stock(b, with: "log", count: 5)
        TestSupport.layBelt(from: GridPoint(0, 3), to: GridPoint(11, 3), in: session)
        TestSupport.layBelt(from: GridPoint(5, 0), to: GridPoint(5, 3), in: session)
        session.advance(ticks: 400)
        let received = try XCTUnwrap(session.world.building(end)?.input)
        XCTAssertEqual(received.count(of: "clay"), 5)
        XCTAssertEqual(received.count(of: "log"), 5)
    }

    func testHeadOnBeltsDoNotPassItems() throws {
        let content = try TestSupport.content()
        var world = World(map: try TileMap.parse("....", content: content), seed: 1)
        var east = BeltTile(point: GridPoint(1, 0), direction: .east, slots: 4, pullsFrom: nil)
        east.slots[3] = "clay"
        world.belts = [east, BeltTile(point: GridPoint(2, 0), direction: .west, slots: 4, pullsFrom: nil)]
        BeltSystem.reorder(&world, content: content)
        var events: [GameEvent] = []
        for _ in 0..<20 { Simulation.step(&world, content: content, events: &events) }
        XCTAssertEqual(world.belt(at: GridPoint(1, 0))?.slots[3], "clay")
        XCTAssertEqual(world.belt(at: GridPoint(2, 0))?.items, [])
    }

    func testLoopKeepsItsItems() throws {
        let content = try TestSupport.content()
        var world = World(map: try TileMap.parse("..\n..", content: content), seed: 1)
        var first = BeltTile(point: GridPoint(0, 0), direction: .east, slots: 4, pullsFrom: nil)
        first.slots = ["clay", nil, "log", nil]
        world.belts = [first,
                       BeltTile(point: GridPoint(1, 0), direction: .south, slots: 4, pullsFrom: nil),
                       BeltTile(point: GridPoint(1, 1), direction: .west, slots: 4, pullsFrom: nil),
                       BeltTile(point: GridPoint(0, 1), direction: .north, slots: 4, pullsFrom: nil)]
        BeltSystem.reorder(&world, content: content)
        var events: [GameEvent] = []
        for _ in 0..<200 { Simulation.step(&world, content: content, events: &events) }
        XCTAssertEqual(world.belts.flatMap(\.items).sorted(), ["clay", "log"])
    }

    func testBeltStockLimitsLength() throws {
        let session = try TestSupport.session(open)
        session.setBeltsAvailable(3)
        guard case let .rejected(.outOfBelts(message)) = session.layBelt(from: GridPoint(0, 0), to: GridPoint(6, 0)) else {
            return XCTFail("Seven tiles do not fit in a stock of three")
        }
        XCTAssertEqual(message, "This belt needs 7 tiles and you have 3")
        XCTAssertEqual(session.world.beltsAvailable, 3)
        XCTAssertEqual(session.layBelt(from: GridPoint(0, 0), to: GridPoint(2, 0)), .ok)
        XCTAssertEqual(session.world.beltsAvailable, 0)
        XCTAssertEqual(session.undo(), .ok)
        XCTAssertEqual(session.world.beltsAvailable, 3)
        XCTAssertTrue(session.world.belts.isEmpty)
    }

    func testRemoveBeltAndUndo() throws {
        let session = try TestSupport.session(open)
        TestSupport.layBelt(from: GridPoint(0, 0), to: GridPoint(4, 0), in: session)
        XCTAssertEqual(session.removeBelt(at: GridPoint(2, 0)), .ok)
        XCTAssertNil(session.world.belt(at: GridPoint(2, 0)))
        XCTAssertEqual(session.world.belts.count, 4)
        XCTAssertEqual(session.undo(), .ok)
        XCTAssertEqual(session.world.belt(at: GridPoint(2, 0))?.direction, .east)
    }

    func testBeltCannotStartOnWater() throws {
        let session = try TestSupport.session(["~...."])
        guard case .rejected(.blocked) = session.layBelt(from: GridPoint(0, 0), to: GridPoint(4, 0)) else {
            return XCTFail("No belt on water")
        }
    }
}
