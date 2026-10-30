import SwiftUI
import GroundworkCore
import GroundworkView

/// The blank-paper opening: the game's name, Play (one world, picked up where
/// it was left), Start over, and settings.
struct TitleView: View {
    @Environment(GameStore.self) private var store
    @State private var confirmingStartOver = false
    @State private var newWorld = false
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
                .frame(height: 110)
                Text("Start with the ground.")
                    .font(.pixel(14))
                    .foregroundStyle(Palette.ink.opacity(0.7))
                    .opacity(introDone ? 1 : 0)
                HStack(alignment: .top, spacing: 24) {
                    VStack(spacing: 10) {
                        TitleButton(title: store.hasTutorialSave ? "Continue tutorial" : "Tutorial") {
                            store.playTutorial()
                        }
                        TitleButton(title: "New world") { newWorld = true }
                        HStack(spacing: 10) {
                            if store.hasTutorialSave {
                                SmallButton(title: "Restart tutorial") { confirmingStartOver = true }
                            }
                            SmallButton(title: "Settings") { settings = true }
                        }
                    }
                    if !store.worlds.isEmpty {
                        WorldList()
                    }
                }
                .padding(.top, 4)
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
        .confirmationDialog("Restart the tutorial?", isPresented: $confirmingStartOver, titleVisibility: .visible) {
            Button("Restart", role: .destructive) { store.restartTutorial() }
            Button("Keep going where I was", role: .cancel) {}
        } message: {
            Text("Everything built in the tutorial will be gone. Your own worlds are kept.")
        }
        .sheet(isPresented: $newWorld) {
            NewWorldView()
        }
        .onChange(of: store.wantsNewWorld) { _, wants in
            if wants {
                store.wantsNewWorld = false
                introDone = true
                newWorld = true
            }
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

/// The player's own worlds: tap to carry on, hold to delete.
struct WorldList: View {
    @Environment(GameStore.self) private var store
    @State private var deleting: GameStore.WorldSlot?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Your worlds").font(.pixel(12)).foregroundStyle(Palette.ink.opacity(0.7))
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 6) {
                    ForEach(store.worlds) { world in
                        Button { store.openWorld(world.id) } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(world.name).font(.pixel(14)).lineLimit(1)
                                Text("Seed \(String(world.seed))").font(.pixel(9)).foregroundStyle(Palette.ink.opacity(0.6))
                            }
                            .frame(width: 200, alignment: .leading)
                            .paperCard()
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Delete world", role: .destructive) { deleting = world }
                        }
                    }
                }
            }
            .frame(maxHeight: 150)
        }
        .foregroundStyle(Palette.ink)
        .confirmationDialog("Delete \(deleting?.name ?? "this world")?",
                            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let world = deleting { store.deleteWorld(world.id) }
                deleting = nil
            }
            Button("Keep it", role: .cancel) { deleting = nil }
        }
    }
}

/// Name a world, pick its seed and how much water, forest and clay it has,
/// and see the map before making it.
struct NewWorldView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var seedText = ""
    @State private var water = Amount.normal
    @State private var forest = Amount.normal
    @State private var clay = Amount.normal
    @State private var preview: NewWorld.Preview?

    private var options: WorldOptions {
        let seed = NewWorld.seed(from: seedText)
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return WorldOptions(name: trimmed.isEmpty ? NewWorld.suggestedName(seed: seed) : trimmed,
                            seed: seed, water: water, forest: forest, clay: clay)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("New world").font(.pixel(18))
                TextField(NewWorld.suggestedName(seed: NewWorld.seed(from: seedText)), text: $name)
                    .font(.pixel(14))
                    .textFieldStyle(.roundedBorder)
                HStack {
                    TextField("Seed", text: $seedText)
                        .font(.pixel(13))
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                    Button { seedText = String(UInt64.random(in: 1...999_999)) } label: {
                        Image(systemName: "dice").frame(width: 36, height: 36)
                    }
                }
                AmountPicker(title: "Water", value: $water)
                AmountPicker(title: "Forest", value: $forest)
                AmountPicker(title: "Clay", value: $clay)
                HStack(spacing: 10) {
                    SmallButton(title: "Cancel") { dismiss() }
                    TitleButton(title: "Make world") {
                        dismiss()
                        store.createWorld(options)
                    }
                }
            }
            .frame(maxWidth: 320)
            MapPreview(preview: preview)
                .frame(width: 200, height: 200)
        }
        .padding(20)
        .foregroundStyle(Palette.ink)
        .background(Palette.paper)
        .onAppear {
            if seedText.isEmpty { seedText = String(UInt64.random(in: 1...999_999)) }
            refresh()
        }
        .onChange(of: options) { _, _ in refresh() }
    }

    private func refresh() { preview = store.preview(options) }
}

struct AmountPicker: View {
    let title: String
    @Binding var value: Amount

    var body: some View {
        HStack {
            Text(title).font(.pixel(12)).frame(width: 60, alignment: .leading)
            Picker(title, selection: $value) {
                Text("Few").tag(Amount.few)
                Text("Normal").tag(Amount.normal)
                Text("Lots").tag(Amount.lots)
            }
            .pickerStyle(.segmented)
        }
    }
}

/// The generated map, one square per tile, with the starting spot marked.
struct MapPreview: View {
    let preview: NewWorld.Preview?

    var body: some View {
        Canvas { context, size in
            guard let preview else { return }
            let cell = min(size.width / CGFloat(preview.width), size.height / CGFloat(preview.height))
            for y in 0..<preview.height {
                for x in 0..<preview.width {
                    let c = preview.colors[y * preview.width + x]
                    context.fill(Path(CGRect(x: CGFloat(x) * cell, y: CGFloat(y) * cell, width: cell + 0.5, height: cell + 0.5)),
                                 with: .color(Color(red: c.r, green: c.g, blue: c.b)))
                }
            }
            let s = preview.start
            context.stroke(Path(ellipseIn: CGRect(x: (CGFloat(s.x) - 2) * cell, y: (CGFloat(s.y) - 2) * cell,
                                                  width: cell * 5, height: cell * 5)),
                           with: .color(Palette.gold), lineWidth: 2)
        }
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Palette.ink, lineWidth: 2))
    }
}

struct SmallButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.pixel(12))
                .foregroundStyle(Palette.ink)
                .frame(minHeight: 36)
                .padding(.horizontal, 6)
                .paperCard()
        }
        .buttonStyle(.plain)
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
