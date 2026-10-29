import XCTest
@testable import GroundworkCore

final class ContentLoadingTests: XCTestCase {
    func testRealContentLoadsWithoutProblems() throws {
        let content = try TestSupport.content()
        XCTAssertEqual(content.items.map(\.id), ["brick", "clay", "log", "plank"])
        XCTAssertEqual(content.recipes.count, 4)
        XCTAssertEqual(content.sources.count, 2)
        XCTAssertEqual(content.buildings.count, 8)
    }

    func testBrickIsMadeByTheKilnFromClayAndLogFuel() throws {
        let content = try TestSupport.content()
        let recipes = content.recipes(producing: "brick")
        XCTAssertEqual(recipes.map(\.id), ["brick"])
        let brick = try XCTUnwrap(recipes.first)
        XCTAssertEqual(brick.building, "brick_kiln")
        XCTAssertEqual(brick.inputs.first { $0.role == .fuel }?.item, "log")
        XCTAssertEqual(brick.inputs.first { $0.role == .material }?.item, "clay")
    }

    func testLookupsByID() throws {
        let content = try TestSupport.content()
        XCTAssertEqual(content.building("cottage")?.cost,
                       [ItemStack(item: "brick", count: 10), ItemStack(item: "plank", count: 6)])
        XCTAssertEqual(content.source("forest")?.item, "log")
        XCTAssertEqual(content.building("brick_kiln")?.width, 2)
        XCTAssertNil(content.item("steel_beam"))
    }

    func testMissingFileIsReportedByName() {
        let empty = FileManager.default.temporaryDirectory.appendingPathComponent("groundwork-missing-\(UUID())")
        XCTAssertThrowsError(try ContentDatabase.load(from: empty)) { error in
            guard case let ContentError.unreadable(file, _) = error else { return XCTFail("\(error)") }
            XCTAssertEqual(file, "levels.json", "Levels load first, to find their maps")
        }
    }

    func testIDsEncodeAsBareStrings() throws {
        let data = try JSONEncoder().encode(ItemStack(item: "clay", count: 2))
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(json.contains("\"item\":\"clay\""), json)
    }
}
