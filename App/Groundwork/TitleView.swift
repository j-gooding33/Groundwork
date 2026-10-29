import SwiftUI
import GroundworkCore

/// The blank-paper opening: the game's name, Play (one world, picked up where
/// it was left), Start over, and settings.
struct TitleView: View {
    @Environment(GameStore.self) private var store
    @State private var confirmingStartOver = false
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
                    TitleButton(title: "Play") { store.play() }
                    if store.hasSave {
                        TitleButton(title: "Start over") { confirmingStartOver = true }
                    }
                    TitleButton(title: "Settings") { settings = true }
                }
                .padding(.top, 8)
            }
        }
        .confirmationDialog("Start over?", isPresented: $confirmingStartOver, titleVisibility: .visible) {
            Button("Start over", role: .destructive) { store.startOver() }
            Button("Keep my world", role: .cancel) {}
        } message: {
            Text("Your world and everything built in it will be gone.")
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
