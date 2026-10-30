import XCTest
@testable import GroundworkCore

final class SplitterAndMilestoneTests: XCTestCase {
    private let field = [
        "..................",
        "..................",
        "..................",
        "..................",
        "..................",
        "..................",
        "..................",
        "..................",
    ]

    func testASplitterSharesOneBeltBetweenTwo() throws {
        let session = try TestSupport.session(field)
        let source = try TestSupport.place("storage_crate", at: GridPoint(1, 3), in: session)
        let splitter = try TestSupport.place("splitter", at: GridPoint(6, 3), in: session)
        let north = try TestSupport.place("storage_crate", at: GridPoint(12, 0), in: session)
        let south = try TestSupport.place("storage_crate", at: GridPoint(12, 7), in: session)
        session.stock(source, with: "log", count: 40)
        XCTAssertEqual(session.layBelt(from: GridPoint(1, 3), to: GridPoint(6, 3)), .ok)
        XCTAssertEqual(session.layBelt(from: GridPoint(6, 3), to: GridPoint(12, 0)), .ok)
        XCTAssertEqual(session.layBelt(from: GridPoint(6, 3), to: GridPoint(12, 7)), .ok)
        session.advance(ticks: 400)
        let a = session.world.building(north)?.input.count(of: "log") ?? 0
        let b = session.world.building(south)?.input.count(of: "log") ?? 0
        XCTAssertGreaterThan(a + b, 20, "Logs flow through the splitter")
        XCTAssertLessThanOrEqual(abs(a - b), 2, "Each side gets half: \(a) and \(b)")
        XCTAssertLessThanOrEqual(session.world.building(splitter)?.input.total ?? 0, 2, "It passes things on, not stores them")
    }

    func testRateAndStoredConditions() {
        XCTAssertEqual(TutorialCondition("rate:brick:20"), .rate("brick", 20))
        XCTAssertEqual(TutorialCondition("stored:plank:50"), .stored("plank", 50))
        XCTAssertNil(TutorialCondition("rate:brick:0"))
    }

    func testMilestonesGoOneByOneAndNameTheTown() throws {
        let session = try GameSession.newWorld(content: try TestSupport.content(),
                                               options: WorldOptions(name: "M", seed: 21))
        XCTAssertEqual(session.milestone?.id, "m_splitter")
        XCTAssertEqual(session.townTitle, "Hamlet")
        XCTAssertNotNil(session.milestoneTip, "Its tip shows")
        session.dismissHint()          // the first-hour hint
        session.dismissHint()          // the milestone tip
        XCTAssertNil(session.milestoneTip)

        let start = try XCTUnwrap(session.startPoint)
        var placed = false
        for dx in 0...8 where !placed { placed = session.place("splitter", at: GridPoint(start.x + dx, start.y)) == .ok }
        XCTAssertTrue(placed)
        XCTAssertTrue(session.drainEvents().contains(.milestoneReached("m_splitter")))
        XCTAssertEqual(session.milestone?.id, "m_cottages_10")
        XCTAssertEqual(session.goal, GoalProgress(text: "Grow to 10 cottages", current: 0, target: 10))
        let loaded = try GameSession.load(try session.save(), content: session.content)
        XCTAssertEqual(loaded.milestone?.id, "m_cottages_10", "Milestones are saved with the world")
    }
}
