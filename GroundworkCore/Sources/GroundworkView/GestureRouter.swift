import GroundworkCore

/// Decides what each gesture does: lay a belt, move the map, zoom, tap a
/// building. The app hands every gesture here and acts on the feedback.
///
/// One finger lays a belt while the belt tool is out and moves the map
/// otherwise. Two fingers always move and zoom the map, so the map can be
/// moved without putting a tool down.
public enum GestureRouter {
    public static func apply(_ gesture: Gesture, input: inout InputController, camera: inout Camera,
                             mapping: ViewMapping, session: GameSession) -> Feedback {
        func tile(_ p: ViewPoint) -> GridPoint {
            camera.tile(at: camera.scenePoint(fromView: mapping.toView(p)))
        }
        func pan(_ dx: Double, _ dy: Double) {
            let d = mapping.toView(dx: dx, dy: dy)
            camera.pan(byView: d.dx, d.dy)
            session.noteUI("panned")
        }
        switch gesture {
        case let .tap(p):
            return input.tap(tile(p), session: session)
        case let .longPress(p):
            return input.longPress(tile(p), session: session)
        case let .dragBegan(p):
            if input.dragDraws { input.dragBegan(tile(p), session: session) }
        case let .dragMoved(p):
            if input.dragDraws { input.dragMoved(tile(p), session: session) }
        case let .dragEnded(p):
            if input.dragDraws { return input.dragEnded(tile(p), session: session) }
        case .dragCancelled:
            input.cancelDrag()
        case let .pan(dx, dy):
            if !input.dragDraws { pan(dx, dy) }
        case let .twoFingerPan(dx, dy):
            pan(dx, dy)
        case let .pinch(factor, center):
            camera.pinch(factor, aroundView: mapping.toView(center))
            session.noteUI("zoomed")
        }
        return .none
    }
}
