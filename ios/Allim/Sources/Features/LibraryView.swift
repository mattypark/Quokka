import SwiftUI
import AllimDesign
import AllimEngine

/// The library: everything saved, newest first, as a masonry contact sheet.
struct LibraryView: View {
    @Environment(AppState.self) private var state
    @State private var importing = false
    @State private var settingsOpen = false

    var body: some View {
        NavigationStack {
            Group {
                if let failure = state.storeFailure {
                    StoreFailure(message: failure)
                } else if state.items.isEmpty {
                    EmptyLibrary { importing = true }
                } else {
                    VStack(spacing: 0) {
                        CollectionBar(
                            authors: state.authors,
                            total: state.total,
                            selected: state.selectedAuthor,
                            onSelect: { state.select(author: $0) }
                        )
                        grid
                    }
                }
            }
            .background(Surface.canvas)
            .navigationTitle("Allim")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Surface.canvas, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { settingsOpen = true } label: {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundStyle(Label.secondary)
                    }
                    .accessibilityLabel("Settings")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { importing = true } label: {
                        Image(systemName: "tray.and.arrow.down")
                            .foregroundStyle(Label.secondary)
                    }
                    .accessibilityLabel("Import from Instagram")
                }
            }
            .sheet(isPresented: $importing) { ImportView() }
            .sheet(isPresented: $settingsOpen) { SettingsView() }
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

/// The empty library.
///
/// The only screen in the app that gets the statement face, and it gets it because this is the
/// one moment with nothing else on it -- no thumbnails, no colour, nothing competing. A
/// ransom-note face here reads as a poster; anywhere with content on it, it would read as
/// noise. The rest of the app stays quiet on purpose so that this lands.
private struct EmptyLibrary: View {
    var onImport: () -> Void = {}

    var body: some View {
        VStack(spacing: Space.roomy) {
            Spacer()

            // Two words, not three, and specifically not "YOUR".
            //
            // Every glyph in this face is a separate found object, and its R is a cutout that
            // carries an apostrophe-e along with it -- so "YOUR" renders as "YOU'RE" and the
            // first screen of the app ships with a grammatical error in 52pt type. The face is
            // worth the constraint, but the constraint is real: check any word set in it, and
            // prefer short ones.
            VStack(spacing: -2) {
                Text("BUILD")
                Text("TASTE")
            }
            .font(Type.statement(58))
            .foregroundStyle(Label.primary)
            .multilineTextAlignment(.center)
                        // One mark, not three words, to anything reading the screen aloud.
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

                Text("or share a post to Allim from any app")
                    .font(Type.caption)
                    .foregroundStyle(Label.tertiary)

                Text("instagram · tiktok · youtube · pinterest · reddit · x")
                    .font(Type.meta(10))
                    .foregroundStyle(Label.dim)
            }
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
