import SwiftUI
import AllimDesign
import AllimEngine

/// The library: everything saved, newest first, as a masonry contact sheet.
struct LibraryView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        NavigationStack {
            Group {
                if let failure = state.storeFailure {
                    StoreFailure(message: failure)
                } else if state.items.isEmpty {
                    EmptyLibrary()
                } else {
                    grid
                }
            }
            .background(Surface.canvas)
            .navigationTitle(state.total > 0 ? "\(state.total) saved" : "Allim")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Surface.canvas, for: .navigationBar)
        }
        .tint(Label.primary)
    }

    private var grid: some View {
        GeometryReader { proxy in
            ScrollView {
                MasonryGrid(
                    items: state.items,
                    columns: Grid.columns,
                    spacing: Grid.gutter,
                    width: proxy.size.width - Grid.gutter * 2
                ) { item, _ in
                    ItemTile(item: item, loader: state.loader)
                        .onAppear {
                            // The keyset cursor makes this safe even when saves land at the
                            // head mid-scroll, which OFFSET paging would not be.
                            if item.id == state.items.last?.id { state.loadMore() }
                        }
                }
                .padding(.horizontal, Grid.gutter)
                .padding(.bottom, Space.section)
            }
        }
    }
}

private struct EmptyLibrary: View {
    var body: some View {
        VStack(spacing: Space.roomy) {
            Wordmark(size: 34, animated: false, showsNative: false)
                .opacity(0.45)
            Text("Share a post to Allim and it lands here.")
                .font(Type.body)
                .foregroundStyle(Label.secondary)
                .multilineTextAlignment(.center)
            Text("instagram · tiktok · youtube · pinterest · reddit · x")
                .font(Type.meta(11))
                .foregroundStyle(Label.tertiary)
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
