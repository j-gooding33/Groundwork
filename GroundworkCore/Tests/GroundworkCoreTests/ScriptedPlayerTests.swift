import XCTest
@testable import GroundworkCore

/// A headless player that plays the whole world, chapter after chapter, using
/// only GameSession and reading where to act from the tutorial's highlights,
/// the way a person follows the pulsing outline.
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

    func testScriptedPlayerCompletesEveryChapter() throws {
        session = try GameSession(content: try TestSupport.content())
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

        // 4:00 The kiln burns through its starting logs. The tutorial stops time
        // and will not go on until the player asks Trace why.
        waitUntil { self.session.tutorialStep?.id == "l1_logs" }
        XCTAssertTrue(session.isPausedByTutorial)
        let pausedAt = session.world.tick
        session.advance(ticks: 100)
        XCTAssertEqual(session.world.tick, pausedAt, "Time waits while Trace is taught")
        let trace = session.trace(.building(kiln))
        XCTAssertEqual(trace.root.reason, "Waiting for logs")
        XCTAssertEqual(trace.firstBroken?.subject, .missingBuilding("lumber_camp"))
        XCTAssertEqual(session.tutorialStep?.id, "l1_lumber", "Using Trace finishes the step")
        XCTAssertFalse(session.isGoalReached, "Five starting logs cannot fill an eight-brick foundation")

        // The player fixes it: a lumber camp on the forest, belted to the kiln.
        let forest = try highlightedTile()
        XCTAssertEqual(session.place("lumber_camp", at: forest), .ok)
        XCTAssertEqual(session.layBelt(from: forest, to: kilnOrigin), .ok)

        // 6:00 The foundation fills.
        waitUntil { self.session.isGoalReached }
        XCTAssertNil(session.tutorialStep, "Tutorial finished")
        XCTAssertEqual(session.goal?.current, 8)
        let events = session.drainEvents()
        XCTAssertTrue(events.contains(.goalReached("world")))
        XCTAssertTrue(events.contains(.chapterComplete(0)))

        // Timing: a quick player has the first belt running well inside two minutes.
        let beltTick = try XCTUnwrap(firstBeltTick)
        XCTAssertLessThan(beltTick, UInt64(2 * Simulation.ticksPerMinute), "First belt by 2:00")
        XCTAssertLessThan(session.world.tick, UInt64(10 * Simulation.ticksPerMinute), "Level done inside 10 minutes")
        let log = session.funTest
        XCTAssertLessThan(try XCTUnwrap(log.secondsToFirstBelt), 120, "Fun test: first belt running inside 2 minutes")
        XCTAssertGreaterThanOrEqual(log.bottlenecksFixed, 1, "Fun test: the log shortage was found and fixed")
        XCTAssertNotNil(log.secondsToFirstFix)
        print("Scripted chapter 1: first belt at tick \(beltTick), goal at tick \(session.world.tick), "
              + "fun test \(log.secondsToFirstBelt ?? -1) s to first belt, \(log.bottlenecksFixed) fixes, "
              + "\(log.commands) commands")

        try playChapter2()
        try playChapter3()

        // Free build: the whole map, every building, no goal.
        XCTAssertTrue(session.beginNextChapter())
        XCTAssertEqual(session.chapter?.id, "free_build")
        XCTAssertNil(session.world.unlocked)
        XCTAssertNil(session.world.beltsAvailable)
        XCTAssertNil(session.world.revealed)
        XCTAssertEqual(session.goal?.text, "Share one belt with a Splitter", "Milestones take over from chapter goals")
        XCTAssertEqual(session.townTitle, "Hamlet")
        XCTAssertNil(session.nextChapter)
        XCTAssertFalse(session.beginNextChapter(), "Free build is the last chapter")
        print("Scripted campaign done at tick \(session.world.tick) with \(session.world.buildings.count) buildings")
    }

    private func playChapter2() throws {
        let before = session.world.buildings.count
        let kiln = try building("brick_kiln")
        XCTAssertFalse(session.isRevealed(GridPoint(37 + 15, 29)), "Chapter 1 land is small")
        XCTAssertEqual(session.nextChapter?.name, "First Belts")
        XCTAssertTrue(session.beginNextChapter())
        XCTAssertFalse(session.beginNextChapter(), "Chapter 2 must be finished first")
        XCTAssertEqual(session.chapterIndex, 1)
        XCTAssertTrue(session.isRevealed(GridPoint(37 + 15, 29)), "More land is drawn")
        XCTAssertEqual(session.world.buildings.count, before + 1, "Everything stays, and the crate appears")
        XCTAssertEqual(session.goal?.current, 0)

        // Belt bricks into the crate that appeared.
        XCTAssertEqual(session.tutorialStep?.id, "c2_crate")
        let crate = try building("storage_crate")
        XCTAssertEqual(session.layBelt(from: kiln.origin, to: crate.origin), .ok)
        waitUntil { self.session.tutorialStep?.id == "c2_trace" }
        XCTAssertTrue(session.isPausedByTutorial)
        session.trace(.building(kiln.id))

        // A second pit, merged into the first belt.
        XCTAssertEqual(session.tutorialStep?.id, "c2_second")
        let second = try highlightedTile()
        XCTAssertEqual(session.place("clay_pit", at: second), .ok)
        let firstPit = try building("clay_pit").id
        let firstBelt = try XCTUnwrap(session.world.belts.first { $0.pullsFrom == firstPit })
        XCTAssertEqual(session.layBelt(from: second, to: firstBelt.next), .ok)
        waitUntil(12000) { self.session.isGoalReached }
        XCTAssertNil(session.tutorialStep)
        XCTAssertTrue(session.drainEvents().contains(.chapterComplete(1)))
    }

    private func playChapter3() throws {
        XCTAssertTrue(session.beginNextChapter())
        XCTAssertEqual(session.chapter?.name, "Stone to Roof")
        XCTAssertTrue(session.world.unlocked?.contains("sawmill") ?? false)
        waitUntil { self.session.tutorialStep?.id == "c3_sawmill" }
        let sawmillAt = try highlightedTile()
        XCTAssertEqual(session.place("sawmill", at: sawmillAt), .ok)
        XCTAssertEqual(session.tutorialStep?.id, "c3_saw_logs")
        let forest = try highlightedTile()
        XCTAssertEqual(session.place("lumber_camp", at: forest), .ok)
        XCTAssertEqual(session.layBelt(from: forest, to: sawmillAt), .ok)
        waitUntil { self.session.tutorialStep?.id == "c3_yard" }
        let yardAt = try highlightedTile()
        XCTAssertEqual(session.place("builders_yard", at: yardAt), .ok)
        XCTAssertEqual(session.layBelt(from: try building("brick_kiln").origin, to: yardAt), .ok)
        XCTAssertEqual(session.layBelt(from: sawmillAt, to: yardAt), .ok)
        waitUntil(12000) { self.session.tutorialStep?.id == "c3_trace" }
        session.trace(.building(try building("cottage").id))
        waitUntil(30000) { self.session.isGoalReached }
        XCTAssertNil(session.tutorialStep)
    }

    func testCannotBuildOnUndrawnLand() throws {
        session = try GameSession(content: try TestSupport.content())
        let far = GridPoint(37, 50)
        XCTAssertFalse(session.isRevealed(far))
        XCTAssertEqual(session.place("clay_pit", at: far), .rejected(.blocked("That land isn't drawn yet")))
    }

    func testStartingAtALaterChapterGivesWhatCameBefore() throws {
        session = try GameSession(content: try TestSupport.content(), chapter: 2)
        XCTAssertEqual(session.chapter?.id, "stone_to_roof")
        XCTAssertEqual(session.world.revealed?.radius, 24)
        XCTAssertTrue(Set(session.world.unlocked ?? []).isSuperset(of: ["clay_pit", "lumber_camp", "brick_kiln",
                                                                         "sawmill", "builders_yard"]))
        XCTAssertTrue(session.world.buildings.contains { $0.type == "storage_crate" }, "Chapter 2's crate")
        let loaded = try GameSession.load(try session.save(), content: session.content)
        XCTAssertEqual(loaded.chapterIndex, 2, "The chapter is saved with the world")
        XCTAssertEqual(loaded.world.revealed, session.world.revealed)
    }
}
