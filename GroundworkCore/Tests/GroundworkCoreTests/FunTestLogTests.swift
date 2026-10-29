import XCTest
@testable import GroundworkCore

final class FunTestLogTests: XCTestCase {
    private let field = [
        "............",
        ".c..........",
        "............",
        ".T..........",
        "............",
    ]

    func testPlayerFixIsCounted() throws {
        let session = try TestSupport.session(field)
        let kiln = try TestSupport.place("brick_kiln", at: GridPoint(6, 1), in: session)
        session.stock(kiln, with: "clay", count: 10)
        session.advance(ticks: 30)
        XCTAssertEqual(session.funTest.firstBlockedTick, 20, "Blocked once the grace period ends")
        XCTAssertNil(session.funTest.firstFixTick)

        // The player fixes it: a lumber camp belted to the kiln.
        try TestSupport.place("lumber_camp", at: GridPoint(1, 3), in: session)
        TestSupport.layBelt(from: GridPoint(1, 3), to: GridPoint(6, 1), in: session)
        session.advance(ticks: 200)
        XCTAssertEqual(session.funTest.bottlenecksFixed, 1)
        let fixed = try XCTUnwrap(session.funTest.firstFixTick)
        XCTAssertGreaterThan(fixed, 30)
        XCTAssertEqual(session.funTest.secondsToFirstFix, Int(fixed - 20) / 10)
        XCTAssertEqual(session.funTest.commands, 3, "Kiln, lumber camp, belt")
        XCTAssertNotNil(session.funTest.firstBeltLaidTick)
        XCTAssertNotNil(session.funTest.firstBeltDeliveryTick)
    }

    func testMachineThatClearsOnItsOwnIsNotAFix() throws {
        let session = try TestSupport.session(field)
        let kiln = try TestSupport.place("brick_kiln", at: GridPoint(6, 1), in: session)
        session.stock(kiln, with: "clay", count: 10)
        session.advance(ticks: 30)
        session.stock(kiln, with: "log", count: 3) // not a player command
        session.advance(ticks: 10)
        XCTAssertEqual(session.world.building(kiln)?.status, .running)
        XCTAssertEqual(session.funTest.bottlenecksFixed, 0)
    }

    func testRejectedCommandsAreNotCounted() throws {
        let session = try TestSupport.session(field)
        session.place("clay_pit", at: GridPoint(5, 4))   // no clay there
        XCTAssertEqual(session.funTest.commands, 0)
        session.place("clay_pit", at: GridPoint(1, 1))
        XCTAssertEqual(session.funTest.commands, 1)
    }

    func testLogIsSaved() throws {
        let session = try TestSupport.session(field)
        session.place("clay_pit", at: GridPoint(1, 1))
        let loaded = try GameSession.load(try session.save(), content: session.content)
        XCTAssertEqual(loaded.funTest, session.funTest)
    }
}
