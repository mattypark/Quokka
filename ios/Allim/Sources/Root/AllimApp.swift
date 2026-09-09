import SwiftUI
import AllimDesign

@main
struct AllimApp: App {
    @State private var state = AppState()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Reports rather than crashes: the type system falls back to the system serif and
        // monospace, so a missing font file is a note, not a blocker.
        let missing = FontRegistration.missingFaces()
        if !missing.isEmpty {
            print("[Allim] Not bundled, using system fallbacks: \(missing.joined(separator: ", "))")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(state)
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
