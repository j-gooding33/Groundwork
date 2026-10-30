import XCTest
import GroundworkCore
@testable import GroundworkView

final class RoadViewTests: XCTestCase {
    private let field = [
        "..............................",
        "..............................",
        "..............................",
        "..............................",
        "..............................",
        "..............................",
        "..............................",
        "..............................",
        "..............................",
        "..............................",
    ]

    func testRoadPiecesJoinUp() throws {
        let session = try ViewTestSupport.session(field)
        session.layRoad(from: GridPoint(2, 5), to: GridPoint(10, 5))
        session.layRoad(from: GridPoint(6, 1), to: GridPoint(6, 5))
        XCTAssertEqual(SceneBuilder.roadPiece(at: GridPoint(4, 5), world: session.world), "road_ew")
        XCTAssertEqual(SceneBuilder.roadPiece(at: GridPoint(6, 5), world: session.world), "road_new")
        XCTAssertEqual(SceneBuilder.roadPiece(at: GridPoint(2, 5), world: session.world), "road_e")
        let builder = try ViewTestSupport.builder()
        let names = Set(builder.staticLayer(session.world).map(\.name))
        XCTAssertTrue(names.contains("road_new"))
        XCTAssertTrue(names.allSatisfy(builder.atlas.has), "Every road piece exists in the atlas")
    }

    func testDragARoadThenSetATruckWithTwoTaps() throws {
        let session = try ViewTestSupport.session(field)
        let depot = try XCTUnwrap(placed("depot", GridPoint(1, 7), session))
        let crate = try XCTUnwrap(placed("storage_crate", GridPoint(26, 7), session))
        session.stock(depot, with: "plank", count: 20)
        var input = InputController()
        input.use(.road)
        XCTAssertTrue(input.dragDraws)
        input.dragBegan(GridPoint(3, 7), session: session)
        input.dragMoved(GridPoint(25, 7), session: session)
        XCTAssertFalse(input.ghost.isEmpty, "A ghost road shows before letting go")
        XCTAssertNil(input.dragEnded(GridPoint(25, 7), session: session).toast)
        input.use(.route)
        XCTAssertEqual(input.tap(GridPoint(1, 7), session: session).toast, "Now tap where the truck delivers")
        XCTAssertNil(input.tap(GridPoint(26, 7), session: session).toast)
        XCTAssertEqual(session.world.trucks.count, 1)
        session.advance(ticks: 40)
        let sprites = try ViewTestSupport.builder().dynamicLayer(session.world, time: RenderTime())
        XCTAssertTrue(sprites.contains { $0.id.hasPrefix("truck:") && $0.name.hasPrefix("vehicle_truck") })
        _ = crate
        let panel = HUDModel.panel(for: try XCTUnwrap(session.world.building(depot)), session: session)
        XCTAssertTrue(panel.lines.contains("Truck takes goods to the Storage Crate"))
    }

    private func placed(_ type: BuildingTypeID, _ at: GridPoint, _ session: GameSession) -> EntityID? {
        guard session.place(type, at: at) == .ok else { return nil }
        return session.world.building(at: at)?.id
    }
}
