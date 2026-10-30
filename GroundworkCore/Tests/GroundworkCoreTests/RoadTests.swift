import XCTest
@testable import GroundworkCore

final class RoadTests: XCTestCase {
    private let field = [
        "..............................",
        "..............................",
        "..............................",
        "..............................",
        "..........~~~~................",
        "..........~~~~................",
        "..............................",
        "..............................",
        "..............................",
        "..............................",
    ]

    func testRoadsGoAroundWaterAndJoin() throws {
        let session = try TestSupport.session(field)
        XCTAssertEqual(session.layRoad(from: GridPoint(2, 5), to: GridPoint(20, 5)), .ok)
        XCTAssertFalse(session.world.roads.contains(GridPoint(11, 5)), "Not through the water")
        XCTAssertTrue(session.world.hasRoad(GridPoint(20, 5)))
        let before = session.world.roads.count
        XCTAssertEqual(session.layRoad(from: GridPoint(15, 0), to: GridPoint(15, 9)), .ok)
        XCTAssertLessThan(session.world.roads.count - before, 11, "Crosses the first road instead of doubling it")
        XCTAssertNotEqual(session.place("storage_crate", at: GridPoint(20, 5)), .ok, "Nothing is built on a road")
        XCTAssertEqual(session.undo(), .ok)
        XCTAssertEqual(session.world.roads.count, before)
    }

    func testATruckCarriesGoodsAlongTheRoad() throws {
        let session = try TestSupport.session(field)
        let depot = try TestSupport.place("depot", at: GridPoint(1, 7), in: session)
        let crate = try TestSupport.place("storage_crate", at: GridPoint(26, 7), in: session)
        session.stock(depot, with: "brick", count: 30)
        guard case .rejected = session.setTruckRoute(from: depot, to: crate) else {
            return XCTFail("No road yet")
        }
        XCTAssertEqual(session.layRoad(from: GridPoint(3, 7), to: GridPoint(25, 7)), .ok)
        XCTAssertEqual(session.setTruckRoute(from: depot, to: crate), .ok)
        session.advance(ticks: 300)
        let delivered = session.world.building(crate)?.input.count(of: "brick") ?? 0
        XCTAssertGreaterThanOrEqual(delivered, 10, "At least one full load arrived")
        XCTAssertEqual(delivered + (session.world.building(depot)?.input.count(of: "brick") ?? 0)
                       + (session.world.trucks.first?.cargo?.count ?? 0), 30, "Nothing lost or made up")
        let target = try XCTUnwrap(session.world.building(crate))
        XCTAssertTrue(BeltSystem.feeders(of: target, in: session.world, content: session.content).contains(depot),
                      "Trace sees the truck as a supply link")
    }

    func testTrucksWaitWhenTheRoadIsCutAndCarryOnWhenItIsBack() throws {
        let session = try TestSupport.session(field)
        let depot = try TestSupport.place("depot", at: GridPoint(1, 7), in: session)
        let crate = try TestSupport.place("storage_crate", at: GridPoint(26, 7), in: session)
        session.stock(depot, with: "brick", count: 30)
        session.layRoad(from: GridPoint(3, 7), to: GridPoint(25, 7))
        session.setTruckRoute(from: depot, to: crate)
        XCTAssertEqual(session.removeRoad(at: GridPoint(14, 7)), .ok)
        XCTAssertTrue(session.world.trucks[0].path.isEmpty)
        session.advance(ticks: 200)
        XCTAssertEqual(session.world.building(crate)?.input.count(of: "brick") ?? 0, 0)
        session.undo()
        XCTAssertFalse(session.world.trucks[0].path.isEmpty, "The road is back")
        session.advance(ticks: 300)
        XCTAssertGreaterThan(session.world.building(crate)?.input.count(of: "brick") ?? 0, 0)
    }

    func testSameRouteAgainRemovesTheTruckAndRemovingABuildingRemovesItsTrucks() throws {
        let session = try TestSupport.session(field)
        let depot = try TestSupport.place("depot", at: GridPoint(1, 7), in: session)
        let crate = try TestSupport.place("storage_crate", at: GridPoint(26, 7), in: session)
        session.layRoad(from: GridPoint(3, 7), to: GridPoint(25, 7))
        session.setTruckRoute(from: depot, to: crate)
        session.setTruckRoute(from: depot, to: crate)
        XCTAssertTrue(session.world.trucks.isEmpty)
        session.setTruckRoute(from: depot, to: crate)
        session.remove(crate)
        XCTAssertTrue(session.world.trucks.isEmpty)
    }

    func testRoadsAndTrucksSurviveSaving() throws {
        let session = try TestSupport.session(field)
        let depot = try TestSupport.place("depot", at: GridPoint(1, 7), in: session)
        let crate = try TestSupport.place("storage_crate", at: GridPoint(26, 7), in: session)
        session.stock(depot, with: "brick", count: 30)
        session.layRoad(from: GridPoint(3, 7), to: GridPoint(25, 7))
        session.setTruckRoute(from: depot, to: crate)
        session.advance(ticks: 50)
        let loaded = try GameSession.load(try session.save(), content: session.content)
        XCTAssertEqual(loaded.world, session.world)
        loaded.advance(ticks: 200)
        session.advance(ticks: 200)
        XCTAssertEqual(try loaded.save(), try session.save(), "Same save, same future")
    }
}
