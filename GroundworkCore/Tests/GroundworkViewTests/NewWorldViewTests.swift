import XCTest
import GroundworkCore
@testable import GroundworkView

final class NewWorldViewTests: XCTestCase {
    func testSeedsFromNumbersAndWords() {
        XCTAssertEqual(NewWorld.seed(from: "1234"), 1234)
        XCTAssertEqual(NewWorld.seed(from: " 1234 "), 1234)
        XCTAssertEqual(NewWorld.seed(from: "River Town"), NewWorld.seed(from: "river town"))
        XCTAssertNotEqual(NewWorld.seed(from: "river town"), NewWorld.seed(from: "river towns"))
    }

    func testPreviewMatchesTheWorldThatGetsMade() throws {
        let content = try ViewTestSupport.content()
        let options = WorldOptions(name: "Fernbrook", seed: 99, water: .lots)
        let preview = try XCTUnwrap(NewWorld.preview(options, content: content))
        let session = try GameSession.newWorld(content: content, options: options)
        XCTAssertEqual(preview.width * preview.height, preview.colors.count)
        XCTAssertEqual(preview.start, session.startPoint)
        let water = session.world.map.terrain.enumerated().filter { $0.element == .water }.map(\.offset)
        XCTAssertTrue(water.allSatisfy { preview.colors[$0] == NewWorld.color(.water) })
    }

    func testANewWorldShowsHintsAndAllTabs() throws {
        let session = try GameSession.newWorld(content: try ViewTestSupport.content(),
                                               options: WorldOptions(name: "A", seed: 3))
        let hud = HUDModel(session: session, input: InputController())
        XCTAssertEqual(hud.tip?.id, "h_clay")
        XCTAssertEqual(hud.goal?.text, "Share one belt with a Splitter", "The first milestone")
        XCTAssertEqual(hud.chapterTitle, "A · Hamlet")
        XCTAssertEqual(hud.tabs, ModeTab.allCases)
        XCTAssertEqual(Set(hud.palette.map(\.title)).count, 18, "Every building the player places, plus belt, road, pipe and truck")
    }

    func testTheTutorialEndsAfterChapterThree() throws {
        // The test town is chapter 3, with its five cottages built by belts.
        let town = try ViewTestSupport.town(ticks: 9000)
        XCTAssertTrue(town.isGoalReached)
        let card = try XCTUnwrap(HUDModel(session: town, input: InputController()).chapterCard)
        XCTAssertTrue(card.tutorialComplete)
        XCTAssertEqual(card.heading, "Tutorial complete!")
        XCTAssertNil(card.next)
        XCTAssertTrue(town.beginNextChapter(), "Keep building: the whole map opens")
        let hud = HUDModel(session: town, input: InputController())
        XCTAssertEqual(hud.goal?.text, "Share one belt with a Splitter", "The five-cottage bar gives way to milestones")
        XCTAssertNil(hud.chapterCard)
    }
}
