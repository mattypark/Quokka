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
    /// Whether the liquid sky is drawn above Home's stack -- a page opening from Home or coming
    /// back to it -- rather than beneath Home, for a change of tab.
    @State private var skyAbove = false
    @State private var skyOpacity: Double = 1
    /// Whether the sky swallows touches. It does while it covers a page that is about to be
    /// swapped, so a tap cannot push something the swap would then pop.
    @State private var holdsTouches = false

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
        // Gone for the whole of a page opening from Home or coming back to it; it returns
        // with Home's words.
        if pouring && skyAbove { return false }
        return switch tab {
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
            // first and Home's words arrive on it. Opening a page from Home uses the same sky
            // drawn above Home's stack instead, so it can drain off the page pushed beneath it.
            ZStack {
                page(.library) {
                    LibraryView(path: $libraryPath, scrollToTop: scrollToTop[.library, default: 0]) {
                        importing = true
                    }
                }
                page(.studio) {
                    StudioView(path: $studioPath, scrollToTop: scrollToTop[.studio, default: 0])
                }
                if pouring, !skyAbove { liquidSky }
                page(.home) {
                    HomeView(
                        path: $homePath,
                        scrollToTop: scrollToTop[.home, default: 0],
                        onImport: { importing = true },
                        onSettings: { showingSettings = true },
                        onLibrary: { select(.library) })
                    .environment(\.skyPassage, SkyPassage(open: openFromHome, back: backToHome))
                }
                if pouring, skyAbove { liquidSky }
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

    /// Home's sky as a liquid, filled to `skyLevel`.
    private var liquidSky: some View {
        SkyBackground(showsSun: true)
            .ignoresSafeArea()
            .mask(LiquidLevel(level: skyLevel).ignoresSafeArea())
            .opacity(skyOpacity)
            .allowsHitTesting(holdsTouches)
            .accessibilityHidden(true)
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
        let liquid = Self.liquid(duration: 0.78)

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

    /// The sky's curve: slow to gather, then quick, then settling -- liquid rather than a
    /// sliding curtain.
    private static func liquid(duration: Double) -> Animation {
        .timingCurve(0.6, 0.02, 0.3, 1, duration: duration)
    }

    /// Opening a page is quicker than changing tab: it is something you asked to see.
    private static let passage = 0.62

    /// Opens a page from Home, draining the sky into it.
    ///
    /// Home's words fade off their own sky, the page is pushed beneath it with no slide of its
    /// own, and the sky drains upward off the page. Touches reach the page while it drains, so
    /// it can be scrolled as it appears. Deeper in the stack it is an ordinary push; under
    /// Reduce Motion, a cut.
    private func openFromHome(_ route: Route) {
        guard !pouring else { return }
        guard homePath.isEmpty else {
            homePath.append(route)
            return
        }
        guard !Motion.reduced else {
            withTransaction(\.disablesAnimations, true) { homePath.append(route) }
            return
        }
        skyAbove = true
        skyLevel = 1
        skyOpacity = 0
        holdsTouches = true
        pouring = true
        Task { @MainActor in
            // One frame for the sky layer to exist before it fades in, as in `select`.
            try? await Task.sleep(for: .milliseconds(16))
            await animate(.easeOut(duration: 0.16)) { skyOpacity = 1 }
            withTransaction(\.disablesAnimations, true) { homePath.append(route) }
            holdsTouches = false
            // Two frames for the page to lay out and read its row, so the drain uncovers a
            // finished page rather than one filling in.
            try? await Task.sleep(for: .milliseconds(32))
            await animate(Self.liquid(duration: Self.passage)) { skyLevel = 0 }
            endPassage()
        }
    }

    /// Goes back one page on Home's stack, pouring the sky over it when that lands on Home.
    ///
    /// The sky pours down over the page, Home is swapped in beneath it, and Home's words arrive
    /// on it -- the tab change's return, over a page instead of a tab. The edge swipe stays the
    /// system's, because a gesture has to follow the finger.
    private func backToHome() {
        guard !pouring, !homePath.isEmpty else { return }
        guard homePath.count == 1 else {
            homePath.removeLast()
            return
        }
        guard !Motion.reduced else {
            withTransaction(\.disablesAnimations, true) { homePath.removeLast() }
            return
        }
        skyAbove = true
        skyLevel = 0
        skyOpacity = 1
        holdsTouches = true
        pouring = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(16))
            await animate(Self.liquid(duration: Self.passage)) { skyLevel = 1 }
            withTransaction(\.disablesAnimations, true) { homePath.removeLast() }
            try? await Task.sleep(for: .milliseconds(32))
            await animate(.easeOut(duration: 0.22)) { skyOpacity = 0 }
            endPassage()
        }
    }

    private func endPassage() {
        pouring = false
        skyAbove = false
        skyOpacity = 1
        holdsTouches = false
    }

    /// Runs an animation and returns once it has finished.
    private func animate(_ animation: Animation, _ change: () -> Void) async {
        await withCheckedContinuation { finished in
            withAnimation(animation, change) { finished.resume() }
        }
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
