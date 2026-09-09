import SwiftUI
import AllimDesign

struct RootView: View {
    @Environment(AppState.self) private var state
    @State private var showingSplash = true

    var body: some View {
        ZStack {
            Surface.canvas.ignoresSafeArea()

            if showingSplash {
                Wordmark { withAnimation(Motion.respecting(.easeOut(duration: 0.3))) { showingSplash = false } }
                    .transition(.opacity)
            } else {
                LibraryView()
                    .transition(.opacity)
            }
        }
        .task {
            state.drainInbox()
            state.importFixtureIfRequested()
        }
    }
}
