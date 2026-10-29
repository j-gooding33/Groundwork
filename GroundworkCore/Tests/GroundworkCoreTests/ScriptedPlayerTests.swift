import XCTest
@testable import GroundworkCore

/// A headless player that completes Level 1 using only GameSession, reading
/// where to act from the tutorial's highlights, the way a person follows the
/// pulsing outline.
final class ScriptedPlayerTests: XCTestCase {
    private var session: GameSession!

    private func waitUntil(_ limit: Int = 6000, file: StaticString = #filePath, line: UInt = #line,
                           _ condition: () -> Bool) {
        var waited = 0
        while !condition() && waited < limit {
            session.advance(ticks: 1)
            waited += 1
        }
        XCTAssertTrue(condition(), "Timed out at tick \(session.world.tick) on step \(session.tutorialStep?.id ?? "none")",
                      file: file, line: line)
    }

    private func highlightedTile() throws -> GridPoint {
        try XCTUnwrap(session.tutorialStep?.highlight?.tile, "Step \(session.tutorialStep?.id ?? "none") has no tile")
    }

    private func building(_ type: BuildingTypeID) throws -> Building {
        try XCTUnwrap(session.world.buildings.first { $0.type == type }, "No \(type)")
    }

    func testScriptedPlayerCompletesLevel1() throws {
        session = try GameSession(content: try TestSupport.content(), level: "level1")
        var firstBeltTick: UInt64?

        // 0:20 Place the clay pit on the highlighted deposit.
        XCTAssertEqual(session.tutorialStep?.id, "l1_ground")
        XCTAssertEqual(session.place("clay_pit", at: try highlightedTile()), .ok)

        // The first clay appears.
        waitUntil { self.session.tutorialStep?.id == "l1_kiln" }

        // 1:00 Place the kiln where the outline shows.
        XCTAssertEqual(session.place("brick_kiln", at: try highlightedTile()), .ok)
        XCTAssertEqual(session.tutorialStep?.id, "l1_carry")

        // Carry the first clay in by hand.
        let pit = try building("clay_pit").id
        let kiln = try building("brick_kiln").id
        waitUntil { (self.session.world.building(pit)?.output.count(of: "clay") ?? 0) >= 2 }
        XCTAssertEqual(session.pickUp(from: pit), .ok)
        XCTAssertEqual(session.drop(into: kiln), .ok)

        // The chime: the first brick pops out.
        waitUntil { self.session.tutorialStep?.id == "l1_belt" }
        XCTAssertEqual(session.world.beltsAvailable, 12, "The starter belt is handed over")

        // 2:00 Drag a belt from the pit to the kiln.
        let pitOrigin = try building("clay_pit").origin
        let kilnOrigin = try building("brick_kiln").origin
        XCTAssertEqual(session.layBelt(from: pitOrigin, to: kilnOrigin), .ok)
        firstBeltTick = session.world.tick
        waitUntil { self.session.tutorialStep?.id == "l1_foundation" }

        // Belt the bricks on to the foundation.
        let foundationOrigin = try building("foundation").origin
        XCTAssertEqual(session.layBelt(from: kilnOrigin, to: foundationOrigin), .ok)

        // 4:00 The kiln burns through its starting logs and Trace shows the gap.
        waitUntil { self.session.tutorialStep?.id == "l1_lumber" }
        let trace = session.trace(.building(kiln))
        XCTAssertEqual(trace.root.reason, "Waiting for logs")
        XCTAssertEqual(trace.firstBroken?.subject, .missingBuilding("lumber_camp"))
        XCTAssertFalse(session.isGoalReached, "Five starting logs cannot fill an eight-brick foundation")

        // The player fixes it: a lumber camp on the forest, belted to the kiln.
        let forest = try highlightedTile()
        XCTAssertEqual(session.place("lumber_camp", at: forest), .ok)
        XCTAssertEqual(session.layBelt(from: forest, to: kilnOrigin), .ok)

        // 6:00 The foundation fills.
        waitUntil { self.session.isGoalReached }
        XCTAssertNil(session.tutorialStep, "Tutorial finished")
        XCTAssertEqual(session.goal?.current, 8)
        XCTAssertTrue(session.drainEvents().contains(.goalReached("level1")))

        // Timing: a quick player has the first belt running well inside two minutes.
        let beltTick = try XCTUnwrap(firstBeltTick)
        XCTAssertLessThan(beltTick, UInt64(2 * Simulation.ticksPerMinute), "First belt by 2:00")
        XCTAssertLessThan(session.world.tick, UInt64(10 * Simulation.ticksPerMinute), "Level done inside 10 minutes")
        let log = session.funTest
        XCTAssertLessThan(try XCTUnwrap(log.secondsToFirstBelt), 120, "Fun test: first belt running inside 2 minutes")
        XCTAssertGreaterThanOrEqual(log.bottlenecksFixed, 1, "Fun test: the log shortage was found and fixed")
        XCTAssertNotNil(log.secondsToFirstFix)
        print("Scripted Level 1: first belt at tick \(beltTick), goal at tick \(session.world.tick), "
              + "fun test \(log.secondsToFirstBelt ?? -1) s to first belt, \(log.bottlenecksFixed) fixes, "
              + "\(log.commands) commands")
    }
}
