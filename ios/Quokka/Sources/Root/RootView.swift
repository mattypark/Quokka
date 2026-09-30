import SwiftUI
import QuokkaDesign

struct RootView: View {
    @Environment(AppState.self) private var state
    @State private var tab: TabBar.Tab = Self.launchTab
    @State private var needsOnboarding = !Self.skipsOnboarding && !UserDefaults.standard.bool(forKey: "quokkaOnboarded")
    @State private var importing = false

    // One stack per tab, held here so the tab bar can pop one to its root when its tab is
    // tapped again, and so switching tabs never loses where a person was.
    @State private var homePath = NavigationPath()
    @State private var libraryPath = NavigationPath()
    @State private var studioPath = NavigationPath()
    @State private var showingSettings = false
    @State private var scrollToTop: [TabBar.Tab: Int] = [:]

    /// Whether onboarding should be skipped for this launch.
    ///
    /// A screenshot run deep-linking to a screen would otherwise be stopped at the first one.
    private static var skipsOnboarding: Bool {
        #if DEBUG
        UserDefaults.standard.string(forKey: "quokkaTab") != nil
            || UserDefaults.standard.string(forKey: "quokkaScreen") != nil
        #else
        false
        #endif
    }

    /// Lets a screenshot run open on a specific tab. Debug-only, so it cannot ship.
    private static var launchTab: TabBar.Tab {
        #if DEBUG
        if let name = UserDefaults.standard.string(forKey: "quokkaTab"),
           let tab = TabBar.Tab(rawValue: name) {
            return tab
        }
        #endif
        return .home
    }

    var body: some View {
        ZStack {
            Surface.canvas.ignoresSafeArea()

            if needsOnboarding {
                OnboardingView {
                    UserDefaults.standard.set(true, forKey: "quokkaOnboarded")
                    withAnimation(Motion.respecting(.easeOut(duration: 0.35))) { needsOnboarding = false }
                }
                .transition(.opacity)
            } else {
                content
                    .transition(.opacity)
            }
        }
        // Light everywhere -- the interface is paper -- except the all-sky first screen, where
        // the status bar needs white text to read.
        .preferredColorScheme(needsOnboarding ? .dark : .light)
        .task {
            state.drainInbox()
            state.importFixtureIfRequested()
            state.seedIdeasIfRequested()
            state.seedSampleTranscriptsIfRequested()
            await state.addLinksIfRequested()
            state.transcribeIfRequested()
        }
    }

    /// The bar steps aside on a pushed screen. An item page ends in its own Save pill and a
    /// playlist in its own action pill -- Cosmos shows one floating control at a time.
    private var showsTabBar: Bool {
        switch tab {
        case .home: homePath.isEmpty
        case .library: libraryPath.isEmpty
        case .studio: studioPath.isEmpty
        }
    }

    private var content: some View {
        ZStack(alignment: .bottom) {
            // All three stay alive, so a tab comes back exactly as it was left -- scroll
            // position, pushed screen and all.
            ZStack {
                page(.home) {
                    HomeView(
                        path: $homePath,
                        scrollToTop: scrollToTop[.home, default: 0],
                        onImport: { importing = true },
                        onSettings: { showingSettings = true },
                        onLibrary: { tab = .library })
                }
                page(.library) {
                    LibraryView(path: $libraryPath, scrollToTop: scrollToTop[.library, default: 0]) {
                        importing = true
                    }
                }
                page(.studio) {
                    StudioView(path: $studioPath, scrollToTop: scrollToTop[.studio, default: 0])
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if showsTabBar {
                TabBar(selection: $tab, onReselect: reselect)
                    .padding(.bottom, Space.snug)
                    .transition(.opacity.combined(with: .offset(y: 12)))
            }
        }
        .animation(Motion.respecting(.easeOut(duration: 0.2)), value: showsTabBar)
        .sheet(isPresented: $importing) { ImportView() }
        .sheet(isPresented: $showingSettings) { SettingsView() }
    }

    private func page(_ which: TabBar.Tab, @ViewBuilder _ view: () -> some View) -> some View {
        view()
            .opacity(tab == which ? 1 : 0)
            .allowsHitTesting(tab == which)
            .accessibilityHidden(tab != which)
    }

    /// A second tap on the open tab goes back to its root, and a tap at the root scrolls to
    /// the top.
    private func reselect(_ which: TabBar.Tab) {
        switch which {
        case .home where !homePath.isEmpty: homePath = NavigationPath()
        case .library where !libraryPath.isEmpty: libraryPath = NavigationPath()
        case .studio where !studioPath.isEmpty: studioPath = NavigationPath()
        default: scrollToTop[which, default: 0] += 1
        }
    }
}
