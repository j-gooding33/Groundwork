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
                    Text(bubble.text)
                        .font(.pixel(13))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Palette.ink)
                        .paperCard()
                        .transition(.opacity)
                        .id(bubble.text)
                }
                Spacer()
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
                if let panel = hud.selection {
                    SelectionCard(panel: panel)
                }
            }
            .padding(.horizontal, 16)

            if hud.levelComplete && !store.completeDismissed && !store.menuOpen {
                LevelCompleteCard()
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
            if let goal = hud.goal {
                HStack(spacing: 8) {
                    SpriteIcon(images: images, name: "icon_goal", size: 20)
                    VStack(alignment: .leading, spacing: 3) {
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
        case .speed: return store.speed == 1 ? "icon_speed_1" : store.speed == 2 ? "icon_speed_2" : "icon_speed_4"
        }
    }

    private func selected(_ tab: ModeTab) -> Bool {
        switch tab {
        case .build: return store.showPalette
        case .trace: return store.input.tool == .trace
        case .demolish: return store.input.tool == .demolish
        default: return false
        }
    }

    private func tap(_ tab: ModeTab) {
        switch tab {
        case .build: store.showPalette.toggle()
        case .trace: store.choose(.trace)
        case .undo: store.undo()
        case .demolish: store.choose(.demolish)
        case .speed: store.cycleSpeed()
        }
    }
}

private struct LevelCompleteCard: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        VStack(spacing: 12) {
            Text("Goal reached!").font(.pixel(22))
            Text(store.hud?.goal?.text ?? "").font(.pixel(12))
            HStack(spacing: 12) {
                if let next = store.nextLevel {
                    TitleButton(title: next.name) { store.newGame(next.id) }
                }
                TitleButton(title: "Keep building") { store.closeCompleteCard() }
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
                TitleButton(title: "Save and quit") { store.quitToTitle() }
            }
            .tint(Palette.grass)
            .foregroundStyle(Palette.ink)
            .paperCard()
        }
    }
}
