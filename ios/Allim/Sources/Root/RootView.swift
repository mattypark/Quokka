import SwiftUI
import AllimDesign

struct RootView: View {
    @Environment(AppState.self) private var state
    @State private var showingSplash = Self.launchTab == .today
    @State private var tab: TabBar.Tab = Self.launchTab
    @State private var needsOnboarding = !Self.skipsOnboarding && !UserDefaults.standard.bool(forKey: "allimOnboarded")
    @State private var importing = false

    /// Whether onboarding should be skipped for this launch.
    ///
    /// A screenshot run deep-linking to a screen would otherwise be stopped at the first one.
    private static var skipsOnboarding: Bool {
        #if DEBUG
        UserDefaults.standard.string(forKey: "allimTab") != nil
            || UserDefaults.standard.string(forKey: "allimScreen") != nil
        #else
        false
        #endif
    }

    /// Lets a screenshot run open on a specific tab. Debug-only, so it cannot ship.
    private static var launchTab: TabBar.Tab {
        #if DEBUG
        if let name = UserDefaults.standard.string(forKey: "allimTab"),
           let tab = TabBar.Tab(rawValue: name) {
            return tab
        }
        #endif
        return .today
    }

    var body: some View {
        ZStack {
            Surface.canvas.ignoresSafeArea()

            if showingSplash {
                Wordmark {
                    withAnimation(Motion.respecting(.easeOut(duration: 0.3))) { showingSplash = false }
                }
                .transition(.opacity)
            } else if needsOnboarding {
                OnboardingView {
                    UserDefaults.standard.set(true, forKey: "allimOnboarded")
                    withAnimation(Motion.respecting(.easeOut(duration: 0.35))) { needsOnboarding = false }
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
            state.seedIdeasIfRequested()
        }
    }

    private var content: some View {
        ZStack(alignment: .bottom) {
            // The grid runs to every edge of the screen. Chrome floats over it.
            Group {
                switch tab {
                case .today: PlannerView()
                case .library: LibraryView(onImport: { importing = true })
                case .playlists: PlaylistsView()
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
