import SwiftUI
import QuokkaDesign

@main
struct QuokkaApp: App {
    @State private var state = AppState()
    @State private var profile = ProfileIdentity()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(state)
                .environment(profile)
                .preferredColorScheme(.light)
        }
        .onChange(of: scenePhase) { _, phase in
            // Saves made through the share sheet land while the app is suspended, so the
            // foreground transition is when they actually arrive.
            if phase == .active {
                state.drainInbox()
                state.syncMirror()
            }
        }
    }
}
