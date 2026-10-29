import Foundation
import Observation
import GroundworkCore
import GroundworkView

/// The app's state: the running GameSession plus everything the screen needs.
/// All decisions live in GroundworkView (tested on Linux); this class only
/// wires them to time, touches, sound and saving.
@MainActor @Observable
final class GameStore {
    enum Screen: Equatable { case title, playing }

    struct Toast: Equatable {
        var id: Int
        var text: String
    }

    // MARK: Shown by SwiftUI

    var screen = Screen.title
    private(set) var hud: HUDModel?
    private(set) var toast: Toast?
    var showPalette = true
    var menuOpen = false
    /// The tutorial bubble the player tucked away; "?" brings it back.
    var collapsedStep: String?
    /// The player closed the chapter card to keep building first.
    private(set) var completeDismissed = false
    private(set) var speed = 1
    private(set) var hasSave = false
    var soundOn = UserDefaults.standard.object(forKey: "soundOn") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(soundOn, forKey: "soundOn")
            feel.soundOn = soundOn
        }
    }
    var hapticsOn = UserDefaults.standard.object(forKey: "hapticsOn") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(hapticsOn, forKey: "hapticsOn")
            feel.hapticsOn = hapticsOn
        }
    }

    // MARK: Engine (not observed)

    @ObservationIgnored let content: ContentDatabase
    @ObservationIgnored let atlas: AtlasManifest
    @ObservationIgnored let builder: SceneBuilder
    @ObservationIgnored private(set) var session: GameSession?
    @ObservationIgnored private(set) var input = InputController()
    @ObservationIgnored private(set) var camera = Camera(mapWidth: 64, mapHeight: 64)
    @ObservationIgnored private var clock = TickClock()
    @ObservationIgnored private var planner = EffectPlanner()
    @ObservationIgnored private var autosave = AutosavePolicy()
    @ObservationIgnored private var touches = TouchTracker()
    @ObservationIgnored let feel = Feel()
    /// Visual effects for the scene to play this frame.
    @ObservationIgnored private(set) var pendingEffects: [Effect] = []
    /// True when the static layer (terrain, trees) must be rebuilt.
    @ObservationIgnored var staticDirty = true
    @ObservationIgnored var mapping = ViewMapping(width: 852, height: 393)
    @ObservationIgnored private var lastFrame: Double?
    @ObservationIgnored private var toastCount = 0
    @ObservationIgnored private var toastExpires = 0.0
    @ObservationIgnored private var now = 0.0

    init() {
        guard let data = Bundle.main.url(forResource: "Data", withExtension: nil),
              let atlasURL = Bundle.main.url(forResource: "atlas", withExtension: "json", subdirectory: "generated") else {
            fatalError("Add Data/ and Art/generated/ to the app as folder references (see docs/INTEGRATION.md)")
        }
        do {
            content = try ContentDatabase.load(from: data)
            atlas = try AtlasManifest.load(from: atlasURL)
        } catch {
            fatalError("Game data failed to load: \(error)")
        }
        builder = SceneBuilder(content: content, atlas: atlas)
        hasSave = FileManager.default.fileExists(atPath: Self.saveURL.path)
        feel.soundOn = soundOn
        feel.hapticsOn = hapticsOn
    }

    // MARK: Starting and stopping

    /// Continues the saved world, or starts it at Chapter 1.
    func play() {
        guard hasSave else { return startFresh() }
        do {
            let data = try Data(contentsOf: Self.saveURL)
            let session = try GameSession.load(data, content: content)
            guard session.chapter != nil else {
                show("That save is from an older version, so a new world began")
                return startFresh()
            }
            start(session)
        } catch {
            show("The save could not be read, so a new world began")
            startFresh()
        }
    }

    /// Throws the saved world away and begins again at Chapter 1.
    func startOver() {
        try? FileManager.default.removeItem(at: Self.saveURL)
        hasSave = false
        startFresh()
    }

    private func startFresh() {
        do {
            start(try GameSession(content: content))
        } catch {
            show("Could not start the world: \(error)")
        }
    }

    private func start(_ session: GameSession) {
        self.session = session
        input = InputController()
        planner = EffectPlanner()
        clock = TickClock()
        speed = 1
        autosave = AutosavePolicy()
        camera = Camera(mapWidth: session.world.map.width, mapHeight: session.world.map.height,
                        focus: session.level?.focus, zoom: 1.5)
        _ = session.drainEvents()
        staticDirty = true
        menuOpen = false
        completeDismissed = false
        screen = .playing
        refreshHUD()
    }

    func quitToTitle() {
        saveNow()
        session = nil
        hud = nil
        screen = .title
    }

    func saveNow() {
        guard let session else { return }
        do {
            try FileManager.default.createDirectory(at: Self.saveURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try session.save().write(to: Self.saveURL, options: .atomic)
            hasSave = true
            autosave.didSave(now: now)
        } catch {
            show("Saving failed: \(error.localizedDescription)")
        }
    }

    static var saveURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("Groundwork/save.json")
    }

    // MARK: The frame loop

    /// Called by the scene every frame with SpriteKit's clock.
    func frame(now: Double) {
        self.now = now
        defer { lastFrame = now }
        guard let session, let last = lastFrame else { return }
        for gesture in touches.update(time: now) { handle(gesture) }
        if !menuOpen {
            session.advance(ticks: clock.ticks(forElapsed: min(now - last, 0.25)))
        }
        let events = session.drainEvents()
        if events.contains(where: Self.changesStructure) { staticDirty = true }
        let effects = planner.plan(events, session: session)
        for effect in effects {
            switch effect {
            case let .haptic(h): feel.haptic(h)
            case let .sound(cue): feel.play(cue)
            case let .musicLayers(n): feel.musicLayers = n
            default: pendingEffects.append(effect)
            }
        }
        feel.update(mix: AudioMix(world: session.world, content: content))
        if toast != nil, now > toastExpires { toast = nil }
        if autosave.shouldSave(now: now) { saveNow() }
        refreshHUD()
    }

    /// Effects for the scene; clears the queue.
    func takeEffects() -> [Effect] {
        defer { pendingEffects.removeAll() }
        return pendingEffects
    }

    var renderTime: RenderTime { RenderTime(fraction: clock.fraction, seconds: now) }

    private static func changesStructure(_ event: GameEvent) -> Bool {
        switch event {
        case .buildingPlaced, .buildingRemoved, .beltLaid, .beltRemoved, .chapterStarted: return true
        default: return false
        }
    }

    private func refreshHUD() {
        guard let session else { return }
        let fresh = HUDModel(session: session, input: input)
        if fresh != hud { hud = fresh }
    }

    // MARK: Touches

    func touchBegan(_ id: Int, _ p: ViewPoint, time: Double) {
        for g in touches.began(id, p, time: time) { handle(g) }
    }

    func touchMoved(_ id: Int, _ p: ViewPoint, time: Double) {
        for g in touches.moved(id, p, time: time) { handle(g) }
    }

    func touchEnded(_ id: Int, _ p: ViewPoint, time: Double) {
        for g in touches.ended(id, p, time: time) { handle(g) }
    }

    func touchCancelled(_ id: Int) {
        for g in touches.cancelled(id) { handle(g) }
    }

    private func handle(_ gesture: Gesture) {
        guard let session, !menuOpen else { return }
        respond(GestureRouter.apply(gesture, input: &input, camera: &camera, mapping: mapping, session: session))
        refreshHUD()
    }

    private func respond(_ feedback: Feedback) {
        if let h = feedback.haptic { feel.haptic(h) }
        if let text = feedback.toast { show(text) }
        if let focus = feedback.focus { camera.focus(on: focus) }
    }

    func show(_ text: String) {
        toastCount += 1
        toast = Toast(id: toastCount, text: text)
        toastExpires = now + 2.5
    }

    // MARK: Buttons

    func choose(_ tool: Tool) {
        input.choose(tool)
        refreshHUD()
    }

    func undo() {
        guard let session else { return }
        if case let .rejected(error) = session.undo() { show(error.message) }
        refreshHUD()
    }

    func cycleSpeed() {
        speed = speed == 1 ? 2 : speed == 2 ? 4 : 1
        clock.speed = speed
    }

    func closePanel() {
        input.clearSelection()
        refreshHUD()
    }

    func pickUpFromSelection() {
        guard let session, let id = input.selection else { return }
        if case let .rejected(error) = session.pickUp(from: id) { show(error.message) }
        refreshHUD()
    }

    func closeCompleteCard() { completeDismissed = true }

    /// Opens the next chapter from the chapter-complete card: more land, new
    /// buildings and the next goal.
    func continueChapter() {
        guard let session, session.beginNextChapter() else { return }
        completeDismissed = false
        input.cancel()
        refreshHUD()
        saveNow()
    }

    func toggleRates() {
        input.toggleRates()
        refreshHUD()
    }

    /// Centres the camera on a building (a tapped Trace row).
    func focus(on id: EntityID) {
        guard let building = session?.world.building(id) else { return }
        camera.focus(on: building.origin)
    }

    func closeTrace() {
        input.cancel()
        refreshHUD()
    }

    func skipTutorial() {
        session?.skipTutorial()
        menuOpen = false
        refreshHUD()
    }

    func toggleMenu() {
        menuOpen.toggle()
        if menuOpen { saveNow() }
    }
}
