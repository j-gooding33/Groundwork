import XCTest
@testable import GroundworkView

final class IntroAnimationTests: XCTestCase {
    func testTenBuildersSpellTheWordInUnderTwoSeconds() {
        XCTAssertEqual(IntroAnimation.word.count, 10)
        XCTAssertEqual(IntroAnimation.builders(at: 0).count, 10, "One builder per letter")
        XCTAssertGreaterThanOrEqual(IntroAnimation.duration, 1.5)
        XCTAssertLessThanOrEqual(IntroAnimation.duration, 2.0)
        XCTAssertTrue(IntroAnimation.bricks(at: 0).isEmpty, "Starts on bare paper")
        let done = IntroAnimation.bricks(at: IntroAnimation.layingSeconds)
        XCTAssertEqual(done.count, IntroAnimation.plan.map(\.count).reduce(0, +))
        XCTAssertTrue(done.allSatisfy(\.placed))
    }

    func testBricksBuildUpFromTheGroundAndNeverOverlap() {
        let mid = IntroAnimation.bricks(at: IntroAnimation.layingSeconds / 2)
        let placed = mid.filter(\.placed)
        XCTAssertFalse(placed.isEmpty)
        XCTAssertLessThan(placed.count, IntroAnimation.plan.map(\.count).reduce(0, +))
        XCTAssertTrue(mid.contains { !$0.placed }, "Some bricks are in the air")
        XCTAssertEqual(placed.map(\.cellY).min(), 0, "Walls start at the bottom")
        let cells = IntroAnimation.plan.flatMap { $0 }.map { "\($0.x),\($0.y)" }
        XCTAssertEqual(Set(cells).count, cells.count)
        XCTAssertTrue(IntroAnimation.plan.allSatisfy { !$0.isEmpty }, "Every letter has bricks")
    }

    func testBuildersFaceTheCameraAndHopAtTheEnd() {
        let end = IntroAnimation.builders(at: (IntroAnimation.layingSeconds + IntroAnimation.duration) / 2)
        XCTAssertTrue(end.allSatisfy { $0.sprite == "person_front_0" && $0.y > IntroAnimation.builderGround })
        XCTAssertTrue(IntroAnimation.builders(at: 0.5).allSatisfy { $0.y + 1.5 <= 0 }, "Builders stand below the letters")
        let working = IntroAnimation.builders(at: 0.5)
        XCTAssertTrue(working.allSatisfy { $0.sprite.hasPrefix("person_side_") })
    }
}
