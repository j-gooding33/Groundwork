import SwiftUI
import SpriteKit
import GroundworkCore
import GroundworkView

/// The world fills the screen; every control sits at an edge within thumb
/// reach. Left: build palette. Top: goal and clock. Right: the selected
/// building. Bottom: mode tabs. Level 1 starts with Build, Trace and Undo.
struct GameView: View {
    @Environment(GameStore.self) private var store
    @State private var scene: WorldScene?
    @State private var images: SpriteImages?

    var body: some View {
        ZStack {
            if let scene {
                SpriteView(scene: scene, preferredFramesPerSecond: 60, options: [.ignoresSiblingOrder])
                    .ignoresSafeArea()
            }
            if let hud = store.hud, let images {
                HUD(hud: hud, images: images)
            }
        }
        .onAppear {
            if scene == nil { scene = WorldScene(store: store) }
            if images == nil { images = SpriteImages(manifest: store.atlas) }
        }
    }
}

private struct HUD: View {
    @Environment(GameStore.self) private var store
    let hud: HUDModel
    let images: SpriteImages

    var body: some View {
        ZStack {
            VStack(spacing: 6) {
                TopBar(hud: hud, images: images)
                if let bubble = hud.tutorial {
                    if store.collapsedStep == bubble.id {
                        // Tucked away: a "?" brings the step back.
                        Button { store.collapsedStep = nil } label: {
                            Text("?").font(.pixel(18)).frame(width: 44, height: 44).paperCard()
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text(bubble.text)
                            .font(.pixel(13))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Palette.ink)
                            .paperCard()
                            .onTapGesture { store.collapsedStep = bubble.id }
                            .transition(.opacity)
                            .id(bubble.text)
                    }
                } else if let tip = hud.tip {
                    HStack(spacing: 8) {
                        Text("TIP").font(.pixel(10)).foregroundStyle(Palette.ember)
                        Text(tip.text).font(.pixel(12)).multilineTextAlignment(.leading)
                        Image(systemName: "xmark").font(.system(size: 10))
                    }
                    .foregroundStyle(Palette.ink)
                    .paperCard()
                    .onTapGesture { store.dismissTip() }
                    .transition(.opacity)
                    .id(tip.id)
                } else if let hint = hud.hint {
                    Text(hint)
                        .font(.pixel(12))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Palette.ink)
                        .paperCard()
                        .opacity(0.9)
                }
                Spacer()
                if let toolHint = hud.toolHint {
                    Text(toolHint)
                        .font(.pixel(11))
                        .foregroundStyle(Palette.ink)
                        .paperCard()
                        .id(toolHint)
                }
                if let hand = hud.hand {
                    Label(hand, systemImage: "hand.raised.fill")
                        .font(.pixel(12))
                        .foregroundStyle(Palette.ink)
                        .paperCard()
                }
                if let toast = store.toast {
                    Text(toast.text)
                        .font(.pixel(12))
                        .foregroundStyle(Palette.paper)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Palette.ink.opacity(0.85), in: Capsule())
                        .id(toast.id)
                }
                Tabs(hud: hud, images: images)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            HStack(alignment: .center) {
                if store.showPalette {
                    BuildPalette(entries: hud.palette, images: images)
                }
                Spacer()
                if !hud.tracePanel.isEmpty {
                    TracePanel(rows: hud.tracePanel)
                } else if let panel = hud.selection {
                    SelectionCard(panel: panel)
                }
            }
            .padding(.horizontal, 16)

            if let card = hud.chapterCard, !store.completeDismissed, !store.menuOpen {
                ChapterCompleteCard(card: card)
            }
            if store.menuOpen {
                PauseMenu()
            }
        }
        .animation(.easeOut(duration: 0.15), value: hud)
    }
}

private struct TopBar: View {
    @Environment(GameStore.self) private var store
    let hud: HUDModel
    let images: SpriteImages

    var body: some View {
        HStack(spacing: 10) {
            Button { store.toggleMenu() } label: {
                SpriteIcon(images: images, name: "icon_pause", size: 28).frame(width: 44, height: 44)
            }
            if hud.chapterCard != nil && store.completeDismissed {
                Button { store.continueChapter() } label: {
                    Text("Next chapter").font(.pixel(12)).foregroundStyle(Palette.ink).paperCard()
                }
                .buttonStyle(.plain)
            }
            if hud.goal == nil, let title = hud.chapterTitle {
                Text(title).font(.pixel(11)).foregroundStyle(Palette.ink).paperCard()
            }
            if let goal = hud.goal {
                HStack(spacing: 8) {
                    SpriteIcon(images: images, name: "icon_goal", size: 20)
                    VStack(alignment: .leading, spacing: 3) {
                        if let title = hud.chapterTitle {
                            Text(title).font(.pixel(9)).foregroundStyle(Palette.ink.opacity(0.65))
                        }
                        Text(goal.text).font(.pixel(11))
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Rectangle().fill(Palette.stone.opacity(0.5))
                                Rectangle().fill(Palette.ember).frame(width: g.size.width * hud.goalFraction)
                            }
                        }
                        .frame(height: 6)
                    }
                    Text("\(goal.current)/\(goal.target)").font(.pixel(12))
                }
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: 360)
                .paperCard()
            }
            Spacer()
            Text(hud.clock)
                .font(.pixel(11))
                .foregroundStyle(Palette.ink)
                .paperCard()
        }
    }
}

private struct BuildPalette: View {
    @Environment(GameStore.self) private var store
    let entries: [PaletteEntry]
    let images: SpriteImages

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 6) {
                ForEach(entries, id: \.title) { entry in
                    Button { store.choose(entry.tool) } label: {
                        VStack(spacing: 2) {
                            SpriteIcon(images: images, name: entry.sprite, size: 30)
                            Text(entry.title).font(.pixel(8)).lineLimit(1)
                            if let badge = entry.badge { Text(badge).font(.pixel(9)).foregroundStyle(Palette.brick) }
                        }
                        .foregroundStyle(Palette.ink)
                        .frame(width: 64, height: 58)
                        .background(entry.isSelected ? Palette.gold : Palette.paper)
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Palette.ink, lineWidth: 2))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxHeight: 250)
    }
}

private struct SelectionCard: View {
    @Environment(GameStore.self) private var store
    let panel: SelectionPanel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(panel.title).font(.pixel(13))
                Spacer()
                Button { store.closePanel() } label: { Image(systemName: "xmark").frame(width: 32, height: 32) }
            }
            if !panel.description.isEmpty {
                Text(panel.description).font(.pixel(10)).foregroundStyle(Palette.ink.opacity(0.7))
            }
            Text(panel.status)
                .font(.pixel(11))
                .foregroundStyle(panel.isBlocked ? Palette.brick : Palette.grass)
            ForEach(panel.lines, id: \.self) { line in
                Text(line).font(.pixel(10))
            }
            HStack {
                if panel.canPickUp {
                    Button("Pick up") { store.pickUpFromSelection() }
                        .font(.pixel(11)).frame(minHeight: 44)
                }
                if panel.isBlocked {
                    Button("Trace") { store.choose(.trace) }
                        .font(.pixel(11)).frame(minHeight: 44)
                }
            }
        }
        .foregroundStyle(Palette.ink)
        .frame(width: 210)
        .paperCard()
    }
}

/// Trace's chain as a list: each step, how it is doing and why. Tap a row
/// to centre the camera on that building.
private struct TracePanel: View {
    @Environment(GameStore.self) private var store
    let rows: [TraceRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Trace").font(.pixel(13))
                Spacer()
                Button { store.closeTrace() } label: { Image(systemName: "xmark").frame(width: 32, height: 32) }
            }
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        Button { if let id = row.target { store.focus(on: id) } } label: {
                            HStack(alignment: .top, spacing: 4) {
                                Text(symbol(row.state)).font(.pixel(10)).foregroundStyle(colour(row.state))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(row.label).font(.pixel(10))
                                    Text(row.reason).font(.pixel(9)).foregroundStyle(Palette.ink.opacity(0.75))
                                }
                            }
                            .padding(.leading, CGFloat(row.depth) * 8)
                            .padding(.vertical, 2)
                            .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
                            .background(row.isBroken ? Palette.gold.opacity(0.35) : Color.clear)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 220)
        }
        .foregroundStyle(Palette.ink)
        .frame(width: 230)
        .paperCard()
    }

    /// Shapes as well as colours, for colour-blind players.
    private func symbol(_ state: TraceState) -> String {
        switch state {
        case .running: return "●"
        case .slow: return "◐"
        case .blocked: return "✕"
        case .notBuilt: return "○"
        }
    }

    private func colour(_ state: TraceState) -> Color {
        switch state {
        case .running: return Palette.grass
        case .slow: return Palette.ember
        case .blocked: return Palette.brick
        case .notBuilt: return Palette.stone
        }
    }
}

private struct Tabs: View {
    @Environment(GameStore.self) private var store
    let hud: HUDModel
    let images: SpriteImages

    var body: some View {
        HStack(spacing: 10) {
            ForEach(hud.tabs, id: \.self) { tab in
                Button { tap(tab) } label: {
                    SpriteIcon(images: images, name: icon(tab), size: 26)
                        .frame(width: 52, height: 44)
                        .background(selected(tab) ? Palette.gold : Palette.paper)
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Palette.ink, lineWidth: 2))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .opacity(tab == .undo && !hud.canUndo ? 0.4 : 1)
                }
                .buttonStyle(.plain)
                .overlay(alignment: .top) {
                    if hud.tutorial?.control == tab.rawValue {
                        Circle().fill(Palette.ember).frame(width: 10, height: 10).offset(y: -8)
                    }
                }
            }
        }
    }

    private func icon(_ tab: ModeTab) -> String {
        switch tab {
        case .build: return "icon_build"
        case .trace: return "icon_trace"
        case .undo: return "icon_undo"
        case .demolish: return "icon_demolish"
        case .rates: return "icon_rates"
        case .speed: return store.speed == 1 ? "icon_speed_1" : store.speed == 2 ? "icon_speed_2" : "icon_speed_4"
        }
    }

    private func selected(_ tab: ModeTab) -> Bool {
        switch tab {
        case .build: return store.showPalette
        case .trace: return store.input.tool == .trace
        case .demolish: return store.input.tool == .demolish
        case .rates: return store.input.showRates
        default: return false
        }
    }

    private func tap(_ tab: ModeTab) {
        switch tab {
        case .build: store.showPalette.toggle()
        case .trace: store.choose(.trace)
        case .undo: store.undo()
        case .demolish: store.choose(.demolish)
        case .rates: store.toggleRates()
        case .speed: store.cycleSpeed()
        }
    }
}

private struct ChapterCompleteCard: View {
    @Environment(GameStore.self) private var store
    let card: ChapterCard

    var body: some View {
        VStack(spacing: 10) {
            Text(card.heading).font(.pixel(20))
            Text(card.name).font(.pixel(14)).foregroundStyle(Palette.ink.opacity(0.7))
            if let next = card.next {
                Text(next).font(.pixel(12))
            }
            HStack(spacing: 12) {
                if card.tutorialComplete {
                    TitleButton(title: "Make a new world") { store.finishTutorialForNewWorld() }
                    TitleButton(title: "Keep building here") { store.continueChapter() }
                } else {
                    TitleButton(title: "Continue") { store.continueChapter() }
                    TitleButton(title: "Stay a while") { store.closeCompleteCard() }
                }
            }
        }
        .foregroundStyle(Palette.ink)
        .paperCard()
    }
}

private struct PauseMenu: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        @Bindable var store = store
        ZStack {
            Palette.ink.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 10) {
                Text("Paused").font(.pixel(22))
                TitleButton(title: "Resume") { store.toggleMenu() }
                Toggle("Sound", isOn: $store.soundOn).font(.pixel(13)).frame(width: 200)
                Toggle("Haptics", isOn: $store.hapticsOn).font(.pixel(13)).frame(width: 200)
                if store.hud?.tutorial != nil {
                    TitleButton(title: "Skip tutorial") { store.skipTutorial() }
                }
                TitleButton(title: "Save and quit") { store.quitToTitle() }
            }
            .tint(Palette.grass)
            .foregroundStyle(Palette.ink)
            .paperCard()
        }
    }
}
