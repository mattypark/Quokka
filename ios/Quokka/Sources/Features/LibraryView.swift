import SwiftUI
import QuokkaDesign
import QuokkaEngine

/// Home: everything saved, newest first, as one uninterrupted field of tiles.
///
/// Cosmos's home, one for one: the mark on the left, two text tabs centered, one glyph on the
/// right, and the grid straight underneath with no title between them. "Saved" and "Creators"
/// stand where "For You" and "Following" do -- the library, and the same library grouped by
/// who made it.
struct LibraryView: View {
    @Environment(AppState.self) private var state
    @Binding var path: NavigationPath
    /// Bumped by the tab bar when Home is tapped while already open.
    var scrollToTop = 0
    var onImport: () -> Void = {}

    @State private var feed: Feed = .saved

    enum Feed: Hashable { case saved, creators }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                TopBar {
                    Wordmark()
                } center: {
                    TextTabs(options: [(.saved, "Saved"), (.creators, "Creators")], selection: $feed)
                } trailing: {
                    Button(action: onImport) {
                        Image(systemName: "plus")
                            .font(.system(size: 19, weight: .medium))
                            .foregroundStyle(Label.primary)
                            .frame(width: Control.circle, height: Control.circle)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityLabel("Import")
                }

                Group {
                    if let failure = state.storeFailure {
                        StoreFailure(message: failure)
                    } else if state.total == 0 {
                        EmptyLibrary(onImport: onImport)
                    } else {
                        switch feed {
                        case .saved: SavedGrid(scrollToTop: scrollToTop)
                        case .creators: CreatorsPane()
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Surface.canvas)
            .toolbar(.hidden, for: .navigationBar)
            .quokkaRoutes()
        }
        .task { openForScreenshot() }
    }

    /// Pushes straight into an item, for screenshot runs. DEBUG-only so it cannot ship.
    private func openForScreenshot() {
        #if DEBUG
        guard UserDefaults.standard.string(forKey: "quokkaScreen") == "item", path.isEmpty else { return }
        let target = state.items.first(where: { $0.thumbnailState == .stored }) ?? state.items.first
        if let id = target?.id { path.append(Route.item(id)) }
        #endif
    }
}

/// The grid itself.
private struct SavedGrid: View {
    @Environment(AppState.self) private var state
    let scrollToTop: Int

    var body: some View {
        GeometryReader { proxy in
            ScrollViewReader { reader in
                ScrollView(showsIndicators: false) {
                    Color.clear.frame(height: 0).id(Self.top)

                    MasonryGrid(
                        items: state.items,
                        columns: Grid.columns,
                        spacing: Grid.gutter,
                        width: proxy.size.width - Grid.margin * 2
                    ) { item, _ in
                        TileLink(item: item, loader: state.loader)
                            .onAppear {
                                // The keyset cursor makes this safe even when saves land at the
                                // head mid-scroll, which OFFSET paging would not be.
                                if item.id == state.items.last?.id { state.loadMore() }
                            }
                    }
                    .padding(.horizontal, Grid.margin)
                    .padding(.top, Space.tight)
                    .padding(.bottom, Grid.bottomInset)
                }
                .onChange(of: scrollToTop) {
                    withAnimation(Motion.respecting(.easeOut(duration: 0.3))) {
                        reader.scrollTo(Self.top, anchor: .top)
                    }
                }
            }
        }
    }

    private static let top = "top"
}

/// The empty library. The one screen with nothing else on it, so the headline can be large.
private struct EmptyLibrary: View {
    var onImport: () -> Void = {}

    var body: some View {
        VStack(spacing: Space.roomy) {
            Spacer()

            Text("Build taste")
                .font(Type.headline)
                .tracking(Type.headlineTracking)
                .foregroundStyle(Label.primary)

            Text("Everything that stopped your thumb, in one place.")
                .font(Type.body)
                .foregroundStyle(Label.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            VStack(spacing: Space.base) {
                Button(action: onImport) {
                    FilledPill(title: "Import from Instagram")
                }
                .buttonStyle(PressStyle())
                Text("or share a post to Quokka from any app")
                    .font(Type.caption)
                    .foregroundStyle(Label.secondary)
            }
            .padding(.bottom, Grid.bottomInset)
        }
        .padding(.horizontal, Space.section)
    }
}

/// A store that will not open is shown, not swallowed. A library that has silently stopped
/// persisting is indistinguishable from an empty one.
private struct StoreFailure: View {
    let message: String

    var body: some View {
        VStack(spacing: Space.base) {
            Text("The library could not be opened")
                .font(Type.title(20))
                .foregroundStyle(Label.primary)
            Text(message)
                .font(Type.caption)
                .foregroundStyle(Label.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(Space.section)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
