import XCTest
import GroundworkCore
@testable import GroundworkView

final class TouchTrackerTests: XCTestCase {
    func testQuickTouchIsATap() {
        var t = TouchTracker()
        XCTAssertEqual(t.began(1, ViewPoint(100, 100), time: 0), [])
        XCTAssertEqual(t.moved(1, ViewPoint(104, 103), time: 0.05), [], "Small wobble is still a tap")
        XCTAssertEqual(t.ended(1, ViewPoint(104, 103), time: 0.1), [.tap(ViewPoint(104, 103))])
    }

    func testHeldTouchIsALongPress() {
        var t = TouchTracker()
        _ = t.began(1, ViewPoint(50, 60), time: 10)
        XCTAssertEqual(t.update(time: 10.2), [])
        XCTAssertEqual(t.update(time: 10.5), [.longPress(ViewPoint(50, 60))])
        XCTAssertEqual(t.ended(1, ViewPoint(50, 60), time: 11), [], "No tap after a long press")
    }

    func testMovingFingerDrags() {
        var t = TouchTracker()
        _ = t.began(1, ViewPoint(0, 0), time: 0)
        XCTAssertEqual(t.moved(1, ViewPoint(20, 0), time: 0.1),
                       [.dragBegan(ViewPoint(0, 0)), .dragMoved(ViewPoint(20, 0)), .pan(dx: 20, dy: 0)])
        XCTAssertEqual(t.moved(1, ViewPoint(25, 5), time: 0.2), [.dragMoved(ViewPoint(25, 5)), .pan(dx: 5, dy: 5)])
        XCTAssertEqual(t.ended(1, ViewPoint(25, 5), time: 0.3), [.dragEnded(ViewPoint(25, 5))])
        XCTAssertEqual(t.update(time: 5), [], "A drag never becomes a long press")
    }

    func testTwoFingersPinch() {
        var t = TouchTracker()
        _ = t.began(1, ViewPoint(100, 100), time: 0)
        _ = t.moved(1, ViewPoint(120, 100), time: 0.05)              // started dragging
        XCTAssertEqual(t.began(2, ViewPoint(200, 100), time: 0.1), [.dragCancelled])
        let gestures = t.moved(2, ViewPoint(220, 100), time: 0.2)
        guard case let .pinch(factor, center)? = gestures.first else { return XCTFail("\(gestures)") }
        XCTAssertEqual(factor, 100.0 / 80.0, accuracy: 1e-9)
        XCTAssertEqual(center, ViewPoint(170, 100))
        XCTAssertEqual(t.ended(2, ViewPoint(220, 100), time: 0.3), [])
        XCTAssertEqual(t.ended(1, ViewPoint(120, 100), time: 0.3), [], "Lifting after a pinch is not a tap")
        _ = t.began(3, ViewPoint(5, 5), time: 1)
        XCTAssertEqual(t.ended(3, ViewPoint(5, 5), time: 1.1), [.tap(ViewPoint(5, 5))], "Back to normal afterwards")
    }

    func testScreenMapsOntoTheSceneView() {
        // An iPhone in landscape, 852x393 points: aspect-fill scales by 852/480.
        let m = ViewMapping(width: 852, height: 393)
        XCTAssertEqual(m.scale, 852.0 / 480.0, accuracy: 1e-9)
        let middle = m.toView(ViewPoint(426, 196.5))
        XCTAssertEqual(middle.x, 240, accuracy: 1e-9)
        XCTAssertEqual(middle.y, 135, accuracy: 1e-9)
        let corner = m.toView(ViewPoint(0, 0))
        XCTAssertEqual(corner.x, 0, accuracy: 1e-9)
        XCTAssertGreaterThan(corner.y, 135, "Top of the screen is the top of the view")
        let drag = m.toView(dx: 852.0 / 480.0 * 10, dy: 0)
        XCTAssertEqual(drag.dx, 10, accuracy: 1e-9)
    }
}
