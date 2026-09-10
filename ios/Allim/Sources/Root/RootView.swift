import SwiftUI
import AllimDesign

struct RootView: View {
    @Environment(AppState.self) private var state
    @State private var showingSplash = true
    @State private var tab: TabBar.Tab = .library
    @State private var importing = false

    var body: some View {
        ZStack {
            Surface.canvas.ignoresSafeArea()

            if showingSplash {
                Wordmark {
                    withAnimation(Motion.respecting(.easeOut(duration: 0.3))) { showingSplash = false }
                }
                .transition(.opacity)
            } else {
                content
                    .transition(.opacity)
            }
        }
        .task {
            state.drainInbox()
            state.importFixtureIfRequested()
        }
    }

    private var content: some View {
        ZStack(alignment: .bottom) {
            // The grid runs to every edge of the screen. Chrome floats over it.
            Group {
                switch tab {
                case .library: LibraryView(onImport: { importing = true })
                case .collections: CollectionsView()
                case .settings: SettingsView(embedded: true)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            TabBar(selection: $tab)
                .padding(.bottom, Space.snug)
        }
        .sheet(isPresented: $importing) { ImportView() }
    }
}
