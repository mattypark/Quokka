import SwiftUI
import QuokkaDesign
import QuokkaEngine

/// Everything saved, newest first, as one uninterrupted field of tiles.
struct LibraryView: View {
    @Environment(AppState.self) private var state
    var onImport: () -> Void = {}

    var body: some View {
        Group {
            if let failure = state.storeFailure {
                StoreFailure(message: failure)
            } else if state.items.isEmpty {
                EmptyLibrary(onImport: onImport)
            } else {
                grid
            }
        }
        .background(Surface.canvas)
    }

    private var grid: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    FloatingHeader(
                        title: state.selectedAuthor ?? "Everything",
                        subtitle: "\(state.total) saved",
                        trailing: {
                            AnyView(
                                Button(action: onImport) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Label.onInverse)
                                        .frame(width: 34, height: 34)
                                        .background(Surface.inverse, in: Circle())
                                }
                                .accessibilityLabel("Import from Instagram")
                            )
                        }
                    )

                    MasonryGrid(
                        items: state.items,
                        columns: Grid.columns,
                        spacing: Grid.gutter,
                        width: proxy.size.width - Grid.margin * 2
                    ) { item, _ in
                        ItemTile(item: item, loader: state.loader)
                            .onAppear {
                                // The keyset cursor makes this safe even when saves land at the
                                // head mid-scroll, which OFFSET paging would not be.
                                if item.id == state.items.last?.id { state.loadMore() }
                            }
                    }
                    .padding(.horizontal, Grid.margin)
                }
                .padding(.bottom, Grid.bottomInset)
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }
}

/// The empty library.
///
/// The only screen with nothing else on it -- no thumbnails, no colour, nothing competing --
/// which is why it is the one place the statement face reads as a poster rather than as noise.
private struct EmptyLibrary: View {
    var onImport: () -> Void = {}

    var body: some View {
        VStack(spacing: Space.roomy) {
            Spacer()


            Text("Build taste")
                .font(Type.headline)
                .tracking(Type.headlineTracking)
                .foregroundStyle(Label.primary)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Build taste")

            Text("Everything that stopped your thumb, in one place.")
                .font(Type.body)
                .foregroundStyle(Label.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, Space.snug)

            Spacer()

            VStack(spacing: Space.base) {
                Button(action: onImport) {
                    Text("Import from Instagram")
                        .font(Type.control)
                        .foregroundStyle(Label.onInverse)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Space.base)
                        .background(Surface.inverse, in: Capsule())
                }
                Text("or share a post to Quokka from any app")
                    .font(Type.caption)
                    .foregroundStyle(Label.tertiary)
            }
            .padding(.bottom, Grid.bottomInset)
        }
        .padding(Space.section)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                .font(Type.meta(11))
                .foregroundStyle(Label.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(Space.section)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
