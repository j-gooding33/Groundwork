import SwiftUI

@main
struct GroundworkApp: App {
    @State private var store = GameStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .statusBarHidden()
                .persistentSystemOverlays(.hidden)
                .preferredColorScheme(.light)
        }
        .onChange(of: scenePhase) { _, phase in
            // Save whenever the app leaves the foreground.
            if phase != .active { store.saveNow() }
        }
    }
}

struct RootView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        switch store.screen {
        case .title: TitleView()
        case .playing: GameView()
        }
    }
}
