import XCTest
@testable import GroundworkCore

final class TickClockTests: XCTestCase {
    func testOneSecondIsTenTicks() {
        var clock = TickClock()
        XCTAssertEqual(clock.ticks(forElapsed: 1.0), 10)
    }

    func testRemainderCarriesToTheNextFrame() {
        var clock = TickClock()
        XCTAssertEqual(clock.ticks(forElapsed: 0.05), 0)
        XCTAssertEqual(clock.ticks(forElapsed: 0.05), 1)
    }

    func testSixtyFramesIsTenTicks() {
        var clock = TickClock()
        let total = (0..<60).reduce(0) { sum, _ in sum + clock.ticks(forElapsed: 1.0 / 60.0) }
        XCTAssertEqual(total, 10)
    }

    func testFastForwardRunsMoreTicks() {
        var clock = TickClock(speed: 4)
        XCTAssertEqual(clock.ticks(forElapsed: 0.5), 20)
    }

    func testPausedRunsNoTicks() {
        var clock = TickClock(speed: 0)
        XCTAssertEqual(clock.ticks(forElapsed: 1.0), 0)
    }

    func testLongStallIsCapped() {
        var clock = TickClock(maxTicksPerFrame: 40)
        XCTAssertEqual(clock.ticks(forElapsed: 30), 40)
        XCTAssertEqual(clock.ticks(forElapsed: 0.1), 1, "Time past the cap is dropped, not queued")
    }
}
