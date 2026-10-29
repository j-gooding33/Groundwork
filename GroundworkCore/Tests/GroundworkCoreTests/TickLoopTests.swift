import XCTest
@testable import GroundworkCore

final class TickLoopTests: XCTestCase {
    private func newSession() throws -> GameSession {
        let content = try TestSupport.content()
        return GameSession(content: content, map: try TestSupport.level1Map(content), seed: 1028)
    }

    func testTickCounterIsExact() throws {
        let session = try newSession()
        XCTAssertEqual(session.world.tick, 0)
        session.advance(ticks: 0)
        XCTAssertEqual(session.world.tick, 0)
        session.advance(ticks: 37)
        XCTAssertEqual(session.world.tick, 37)
    }

    func testFastForwardMatchesSingleTicks() throws {
        let fast = try newSession()
        let slow = try newSession()
        fast.advance(ticks: 1000)
        for _ in 0..<1000 { slow.advance(ticks: 1) }
        XCTAssertEqual(try fast.save(), try slow.save())
    }

    func testSaveLoadThenRunMatchesUninterruptedRun() throws {
        let straight = try newSession()
        straight.advance(ticks: 1000)

        let first = try newSession()
        first.advance(ticks: 400)
        let resumed = try GameSession.load(try first.save(), content: first.content)
        XCTAssertEqual(resumed.world, first.world)
        resumed.advance(ticks: 600)

        XCTAssertEqual(try resumed.save(), try straight.save())
    }

    func testSaveIsStableBytes() throws {
        let session = try newSession()
        session.advance(ticks: 5)
        let saved = try session.save()
        XCTAssertEqual(try GameSession.load(saved, content: session.content).save(), saved)
    }
}
