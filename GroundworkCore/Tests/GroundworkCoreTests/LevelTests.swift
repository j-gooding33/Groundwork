import XCTest
@testable import GroundworkCore

final class LevelTests: XCTestCase {
    private func level1() throws -> GameSession {
        try GameSession(content: try TestSupport.content(), level: "level1")
    }

    func testLevel1StartsWithOneBuildingAndNoBelts() throws {
        let session = try level1()
        XCTAssertEqual(session.level?.name, "Bare Ground")
        XCTAssertEqual(session.world.unlocked, ["clay_pit"])
        XCTAssertEqual(session.world.beltsAvailable, 0)
        XCTAssertEqual(session.world.buildings.map(\.type), ["foundation"])
        XCTAssertEqual(session.tutorialStep?.id, "l1_ground")
        XCTAssertEqual(session.tutorialStep?.text, "Start with the ground.")
        XCTAssertEqual(session.goal, GoalProgress(text: "Fill the foundation with bricks", current: 0, target: 8))
        let focus = try XCTUnwrap(session.level?.focus)
        let clayNear = session.world.map.deposits.contains {
            $0.source == "clay_deposit" && abs($0.point.x - focus.x) <= 3 && abs($0.point.y - focus.y) <= 3
        }
        XCTAssertTrue(clayNear, "The camera opens on the clay deposit")
    }

    func testFirstStepWaitsForThePlayer() throws {
        let session = try level1()
        session.advance(ticks: 500)
        XCTAssertEqual(session.world.tick, 0, "Time waits on the first step")
        guard case .rejected(.notUnlocked) = session.place("brick_kiln", at: GridPoint(41, 28)) else {
            return XCTFail("Only the clay pit to begin with")
        }
        XCTAssertEqual(session.place("clay_pit", at: GridPoint(37, 29)), .ok)
        XCTAssertEqual(session.tutorialStep?.id, "l1_source")
        session.advance(ticks: 30)
        XCTAssertEqual(session.world.tick, 30)
        XCTAssertEqual(session.tutorialStep?.id, "l1_kiln", "The first clay finishes the step")
        XCTAssertEqual(session.world.unlocked, ["clay_pit", "brick_kiln"])
    }

    func testFirstKilnGetsItsStartingLogs() throws {
        let session = try level1()
        session.place("clay_pit", at: GridPoint(37, 29))
        session.advance(ticks: 30)
        session.place("brick_kiln", at: GridPoint(41, 28))
        let kiln = try TestSupport.id(at: GridPoint(41, 28), in: session)
        XCTAssertEqual(session.world.building(kiln)?.input.count(of: "log"), 5)
        session.undo()
        session.place("brick_kiln", at: GridPoint(41, 28))
        let second = try TestSupport.id(at: GridPoint(41, 28), in: session)
        XCTAssertEqual(session.world.building(second)?.input.count(of: "log"), 0, "Only the first kiln is stocked")
    }

    func testStepsFinishEvenIfTheirMomentPassedEarlier() throws {
        let session = try level1()
        // Jump ahead: the player carries clay before the tutorial asks.
        session.place("clay_pit", at: GridPoint(37, 29))
        session.advance(ticks: 60)
        session.place("brick_kiln", at: GridPoint(41, 28))
        let pit = try TestSupport.id(at: GridPoint(37, 29), in: session)
        let kiln = try TestSupport.id(at: GridPoint(41, 28), in: session)
        session.pickUp(from: pit)
        session.drop(into: kiln)
        XCTAssertEqual(session.tutorialStep?.id, "l1_first_brick", "Carrying already happened, so that step is done")
    }

    func testLevelStateSurvivesSaveAndLoad() throws {
        let session = try level1()
        session.place("clay_pit", at: GridPoint(37, 29))
        session.advance(ticks: 45)
        let loaded = try GameSession.load(try session.save(), content: session.content)
        XCTAssertEqual(loaded.world, session.world)
        XCTAssertEqual(loaded.tutorialStep?.id, session.tutorialStep?.id)
        loaded.advance(ticks: 100)
        session.advance(ticks: 100)
        XCTAssertEqual(try loaded.save(), try session.save())
    }

    func testTutorialTextIsShort() throws {
        let content = try TestSupport.content()
        for (key, steps) in content.tutorials {
            for step in steps {
                let lines = step.text.split(separator: "\n")
                XCTAssertLessThanOrEqual(lines.count, 2, "\(key)/\(step.id)")
                for line in lines {
                    XCTAssertLessThanOrEqual(line.count, ContentDatabase.maxTutorialLineLength, "\(key)/\(step.id)")
                }
            }
        }
    }

    func testBadTutorialConditionIsRejected() throws {
        XCTAssertNil(TutorialCondition("teleported:clay"))
        XCTAssertEqual(TutorialCondition("delivered:brick:foundation"), .delivered("brick", qualifier: "foundation"))
        XCTAssertEqual(TutorialCondition("goal"), .goal)
    }
}
