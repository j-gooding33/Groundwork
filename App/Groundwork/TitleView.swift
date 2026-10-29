import SwiftUI
import GroundworkCore

/// The blank-paper opening: the game's name, Continue, New game with level
/// select, and settings.
struct TitleView: View {
    @Environment(GameStore.self) private var store
    @State private var choosingLevel = false
    @State private var settings = false

    var body: some View {
        @Bindable var store = store
        ZStack {
            Palette.paper.ignoresSafeArea()
            // Faint pencil grid, like paper waiting for land to be imagined onto it.
            Canvas { context, size in
                let step: CGFloat = 24
                var x: CGFloat = 0
                while x < size.width {
                    context.stroke(Path { $0.move(to: CGPoint(x: x, y: 0)); $0.addLine(to: CGPoint(x: x, y: size.height)) },
                                   with: .color(Palette.sand.opacity(0.18)), lineWidth: 1)
                    x += step
                }
                var y: CGFloat = 0
                while y < size.height {
                    context.stroke(Path { $0.move(to: CGPoint(x: 0, y: y)); $0.addLine(to: CGPoint(x: size.width, y: y)) },
                                   with: .color(Palette.sand.opacity(0.18)), lineWidth: 1)
                    y += step
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 18) {
                Text("GROUNDWORK")
                    .font(.pixel(44))
                    .foregroundStyle(Palette.ink)
                    .shadow(color: Palette.sand, radius: 0, x: 3, y: 3)
                Text("Start with the ground.")
                    .font(.pixel(14))
                    .foregroundStyle(Palette.ink.opacity(0.7))
                VStack(spacing: 10) {
                    if store.hasSave {
                        TitleButton(title: "Continue") { store.continueGame() }
                    }
                    TitleButton(title: "New game") { choosingLevel = true }
                    TitleButton(title: "Settings") { settings = true }
                }
                .padding(.top, 8)
            }
        }
        .sheet(isPresented: $choosingLevel) {
            LevelPicker { level in
                choosingLevel = false
                store.newGame(level)
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $settings) {
            SettingsView().presentationDetents([.medium])
        }
    }
}

struct TitleButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.pixel(18))
                .foregroundStyle(Palette.ink)
                .frame(minWidth: 200, minHeight: 44)
                .paperCard()
        }
        .buttonStyle(.plain)
    }
}

struct LevelPicker: View {
    @Environment(GameStore.self) private var store
    let start: (LevelID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose a level").font(.pixel(18))
            ForEach(store.levels, id: \.id) { level in
                Button { start(level.id) } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(level.name).font(.pixel(16))
                        Text(level.goal.text).font(.pixel(12)).foregroundStyle(Palette.ink.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .paperCard()
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .foregroundStyle(Palette.ink)
        .background(Palette.paper)
    }
}

struct SettingsView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        @Bindable var store = store
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings").font(.pixel(18))
            Toggle("Sound", isOn: $store.soundOn).font(.pixel(14))
            Toggle("Haptics", isOn: $store.hapticsOn).font(.pixel(14))
            Spacer()
        }
        .padding(20)
        .tint(Palette.grass)
        .foregroundStyle(Palette.ink)
        .background(Palette.paper)
    }
}
