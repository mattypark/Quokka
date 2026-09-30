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
    /// How much of the screen the liquid sky covers during a change to or from Home.
    @State private var skyLevel: CGFloat = 0
    @State private var pouring = false

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
            await demoTransitionIfRequested()
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
            // Home is on top, and the liquid sky sits between it and the other two -- so when
            // Home's words fade, what is left on screen is its own sky, which then drains off
            // the top to show the page underneath. Coming back, the sky pours down over the page
            // first and Home's words arrive on it.
            ZStack {
                page(.library) {
                    LibraryView(path: $libraryPath, scrollToTop: scrollToTop[.library, default: 0]) {
                        importing = true
                    }
                }
                page(.studio) {
                    StudioView(path: $studioPath, scrollToTop: scrollToTop[.studio, default: 0])
                }
                if pouring {
                    SkyBackground(showsSun: true)
                        .ignoresSafeArea()
                        .mask(LiquidLevel(level: skyLevel).ignoresSafeArea())
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                page(.home) {
                    HomeView(
                        path: $homePath,
                        scrollToTop: scrollToTop[.home, default: 0],
                        onImport: { importing = true },
                        onSettings: { showingSettings = true },
                        onLibrary: { select(.library) })
                    .environment(\.skyPassage, SkyPassage(open: openFromHome, back: backToHome))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if showsTabBar {
                TabBar(selection: tab, onSelect: select, onReselect: reselect)
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

    /// Changes tab, draining or pouring the sky when Home is one end of the change.
    ///
    /// Leaving Home: its words fade, its sky stays as the liquid layer and drains upward off the
    /// screen. Arriving at Home: the sky pours down over the page, then Home's words arrive on
    /// it. Between Library and Studio there is no sky, so it is a short crossfade. Under Reduce
    /// Motion every change is a plain cut.
    private func select(_ next: TabBar.Tab) {
        guard next != tab, !pouring else { return }
        guard !Motion.reduced else {
            tab = next
            return
        }
        let liquid = Animation.timingCurve(0.6, 0.02, 0.3, 1, duration: 0.78)

        if tab == .home {
            skyLevel = 1
            pouring = true
            withAnimation(.easeOut(duration: 0.18)) { tab = next }
            Task { @MainActor in
                // One frame for the sky layer to exist at full height before it starts to
                // move; animated in the same update, it would have nothing to animate from.
                try? await Task.sleep(for: .milliseconds(16))
                withAnimation(liquid) { skyLevel = 0 } completion: { pouring = false }
            }
        } else if next == .home {
            skyLevel = 0
            pouring = true
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(16))
                withAnimation(liquid) { skyLevel = 1 } completion: {
                    withAnimation(.easeOut(duration: 0.22)) { tab = .home } completion: { pouring = false }
                }
            }
        } else {
            withAnimation(.easeOut(duration: 0.2)) { tab = next }
        }
    }

    /// Pushes onto Home's stack.
    private func openFromHome(_ route: Route) {
        homePath.append(route)
    }

    /// Pops one page off Home's stack.
    private func backToHome() {
        guard !homePath.isEmpty else { return }
        homePath.removeLast()
    }

    /// Drains to the Library and pours back to Home on its own, so the transition can be
    /// recorded without a hand on the simulator. DEBUG-only; `-quokkaDemoTransition YES`.
    private func demoTransitionIfRequested() async {
        #if DEBUG
        guard UserDefaults.standard.bool(forKey: "quokkaDemoTransition") else { return }
        try? await Task.sleep(for: .seconds(3))
        select(.library)
        try? await Task.sleep(for: .seconds(2.5))
        select(.home)
        #endif
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
