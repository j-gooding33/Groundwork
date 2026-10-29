import XCTest
@testable import GroundworkCore

final class ShortageTests: XCTestCase {
    func testKilnBurningItsLastLogsPredictsRunningOut() throws {
        let session = try TestSupport.session(["............", "............", "............"])
        let kiln = try TestSupport.place("brick_kiln", at: GridPoint(5, 0), in: session)
        session.stock(kiln, with: "clay", count: 30)
        session.stock(kiln, with: "log", count: 10)
        session.advance(ticks: 299)

        // Batches start on ticks 1, 51, ... 251: 6 logs burned in 299 ticks
        // (12 a minute), none arriving, 4 left.
        let logs = try XCTUnwrap(session.rates(of: kiln).first { $0.item == "log" })
        XCTAssertEqual(logs.used, 12)
        XCTAssertEqual(logs.received, 0)
        XCTAssertEqual(session.world.building(kiln)?.input.count(of: "log"), 4)
        XCTAssertEqual(logs.runsOutInSeconds, 20)
    }

    func testWellFedKilnPredictsNothing() throws {
        let session = try TestSupport.session([
            "....................",
            ".cc.................",
            "....................",
            "....................",
            ".TT.................",
            "....................",
        ])
        try TestSupport.place("clay_pit", at: GridPoint(1, 1), in: session)
        try TestSupport.place("clay_pit", at: GridPoint(2, 1), in: session)
        try TestSupport.place("lumber_camp", at: GridPoint(1, 4), in: session)
        let kiln = try TestSupport.place("brick_kiln", at: GridPoint(8, 2), in: session)
        TestSupport.layBelt(from: GridPoint(1, 1), to: GridPoint(8, 2), in: session)
        TestSupport.layBelt(from: GridPoint(2, 1), to: GridPoint(8, 2), in: session)
        TestSupport.layBelt(from: GridPoint(1, 4), to: GridPoint(8, 2), in: session)
        try TestSupport.place("storage_crate", at: GridPoint(14, 2), in: session)
        TestSupport.layBelt(from: GridPoint(8, 2), to: GridPoint(14, 2), in: session)
        session.advance(ticks: 1200)
        for rate in session.rates(of: kiln) {
            XCTAssertNil(rate.runsOutInSeconds, "\(rate.item): \(rate)")
        }
    }
}
