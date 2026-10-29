import XCTest
@testable import GroundworkCore

final class TileMapTests: XCTestCase {
    func testLevel1Is64By64() throws {
        let map = try TestSupport.level1Map(try TestSupport.content())
        XCTAssertEqual(map.width, 64)
        XCTAssertEqual(map.height, 64)
        XCTAssertEqual(map.terrain.count, 64 * 64)
    }

    func testLevel1HasClayBesideTheLake() throws {
        let map = try TestSupport.level1Map(try TestSupport.content())
        let clay = map.deposits.filter { $0.source == "clay_deposit" }
        XCTAssertFalse(clay.isEmpty)
        XCTAssertTrue(clay.allSatisfy { $0.remaining == 200 })
        let besideWater = clay.contains { deposit in
            deposit.point.neighbours.contains { map.terrain(at: $0) == .water }
        }
        XCTAssertTrue(besideWater, "The opening shot needs a clay deposit beside the lake")
    }

    func testLevel1HasAForestThatGivesLogs() throws {
        let content = try TestSupport.content()
        let map = try TestSupport.level1Map(content)
        let forest = map.deposits.filter { $0.source == "forest" }
        XCTAssertGreaterThan(forest.count, 50)
        XCTAssertTrue(forest.allSatisfy { map.terrain(at: $0.point) == .forest })
        XCTAssertEqual(content.source("forest")?.item, "log")
    }

    func testDepositsAreSortedAndFoundByPoint() throws {
        let map = try TestSupport.level1Map(try TestSupport.content())
        XCTAssertEqual(map.deposits.map(\.point), map.deposits.map(\.point).sorted())
        for deposit in map.deposits {
            XCTAssertEqual(map.deposit(at: deposit.point), deposit)
        }
        let water = try XCTUnwrap(map.terrain.firstIndex(of: .water))
        XCTAssertNil(map.deposit(at: GridPoint(water % map.width, water / map.width)))
    }

    func testSmallMapParses() throws {
        let map = try TileMap.parse("..c\n~~.\n", content: try TestSupport.fixture())
        XCTAssertEqual(map.width, 3)
        XCTAssertEqual(map.height, 2)
        XCTAssertEqual(map.terrain(at: GridPoint(2, 0)), .clayGround)
        XCTAssertEqual(map.terrain(at: GridPoint(0, 1)), .water)
        XCTAssertEqual(map.deposits, [SourceDeposit(point: GridPoint(2, 0), source: "clay_deposit", remaining: 40)])
    }

    func testBoundsChecks() throws {
        let map = try TileMap.parse("..\n..", content: try TestSupport.fixture())
        XCTAssertTrue(map.contains(GridPoint(1, 1)))
        XCTAssertFalse(map.contains(GridPoint(2, 0)))
        XCTAssertFalse(map.contains(GridPoint(0, -1)))
        XCTAssertNil(map.terrain(at: GridPoint(-1, 0)))
    }

    func testRaggedRowIsRejected() throws {
        XCTAssertThrowsError(try TileMap.parse("...\n..\n", content: try TestSupport.fixture())) {
            XCTAssertEqual($0 as? MapError, .raggedRow(row: 1, width: 2, expected: 3))
        }
    }

    func testUnknownCharacterIsRejected() throws {
        XCTAssertThrowsError(try TileMap.parse("..\n.?\n", content: try TestSupport.fixture())) {
            XCTAssertEqual($0 as? MapError, .unknownCharacter("?", row: 1, column: 1))
        }
    }

    func testEmptyMapIsRejected() throws {
        XCTAssertThrowsError(try TileMap.parse("\n\n", content: try TestSupport.fixture())) {
            XCTAssertEqual($0 as? MapError, .empty)
        }
    }

    func testDirections() {
        let p = GridPoint(5, 5)
        XCTAssertEqual(p.moved(.north), GridPoint(5, 4))
        XCTAssertEqual(p.moved(.east, by: 3), GridPoint(8, 5))
        XCTAssertEqual(Direction.west.opposite, .east)
        XCTAssertEqual(Direction.north.turnedRight, .east)
        XCTAssertEqual(Direction.north.turnedLeft, .west)
        XCTAssertEqual(p.neighbours, [GridPoint(5, 4), GridPoint(6, 5), GridPoint(5, 6), GridPoint(4, 5)])
    }
}
