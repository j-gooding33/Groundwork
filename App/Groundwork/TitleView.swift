import SwiftUI
import GroundworkCore
import GroundworkView

/// The blank-paper opening: the game's name, Play (one world, picked up where
/// it was left), Start over, and settings.
struct TitleView: View {
    @Environment(GameStore.self) private var store
    @State private var confirmingStartOver = false
    @State private var settings = false
    /// When the intro began; the buttons appear once it has played.
    @State private var introStart: Date?
    @State private var introDone = false
    @State private var images: SpriteImages?

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
                TimelineView(.animation(paused: introDone)) { timeline in
                    let t = introDone ? IntroAnimation.duration
                        : timeline.date.timeIntervalSince(introStart ?? timeline.date)
                    BrickWord(t: t, images: images)
                        .onChange(of: t >= IntroAnimation.duration) { _, finished in
                            if finished { withAnimation(.easeOut(duration: 0.3)) { introDone = true } }
                        }
                }
                .frame(height: 130)
                Text("Start with the ground.")
                    .font(.pixel(14))
                    .foregroundStyle(Palette.ink.opacity(0.7))
                    .opacity(introDone ? 1 : 0)
                VStack(spacing: 10) {
                    TitleButton(title: "Play") { store.play() }
                    if store.hasSave {
                        TitleButton(title: "Start over") { confirmingStartOver = true }
                    }
                    TitleButton(title: "Settings") { settings = true }
                }
                .padding(.top, 8)
                .opacity(introDone ? 1 : 0)
                .allowsHitTesting(introDone)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // A tap skips the intro.
            if !introDone { withAnimation(.easeOut(duration: 0.2)) { introDone = true } }
        }
        .onAppear {
            if images == nil { images = SpriteImages(manifest: store.atlas) }
            if introStart == nil { introStart = Date() }
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

/// The word GROUNDWORK in bricks, laid by ten builders (IntroAnimation
/// decides where everything is at time `t`; this only draws it).
struct BrickWord: View {
    let t: Double
    let images: SpriteImages?

    var body: some View {
        Canvas { context, size in
            let cols = Double(IntroAnimation.width), rows = Double(IntroAnimation.height) + 2.5
            let cell = floor(min(size.width * 0.9 / cols, size.height / rows))
            let originX = (size.width - cols * cell) / 2
            let groundY = size.height - cell * 3.5
            func point(_ x: Double, _ y: Double) -> CGPoint {
                CGPoint(x: originX + x * cell, y: groundY - (y + 1) * cell)
            }
            for brick in IntroAnimation.bricks(at: t) {
                let p = point(brick.x, brick.y)
                let rect = CGRect(x: p.x, y: p.y, width: cell - 1, height: cell - 1)
                context.fill(Path(rect), with: .color(Palette.brick))
                context.fill(Path(CGRect(x: rect.minX, y: rect.maxY - max(1, cell / 5), width: rect.width,
                                         height: max(1, cell / 5))),
                             with: .color(Palette.ink.opacity(0.35)))
            }
            guard let images else { return }
            for builder in IntroAnimation.builders(at: t) {
                let w = cell * 1.4, h = w * 1.5
                let foot = point(builder.x, builder.y - 1)
                var c = context
                c.translateBy(x: foot.x + cell / 2, y: foot.y)
                if builder.facingLeft { c.scaleBy(x: -1, y: 1) }
                c.draw(images.image(builder.sprite).interpolation(.none),
                       in: CGRect(x: -w / 2, y: -h, width: w, height: h))
            }
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
