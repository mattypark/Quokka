import SwiftUI
import AllimDesign
import AllimEngine

/// The playlists a person made, and a way through to the ones the app derived.
///
/// The two are kept apart deliberately. A playlist is a decision; grouping by creator is a
/// fact about the data. Mixing them into one list would suggest deleting "kitchen.studio"
/// means something, when there is nothing there to delete.
struct PlaylistsView: View {
    @Environment(AppState.self) private var state

    @State private var summaries: [PlaylistSummary] = []
    @State private var open: Int64?
    @State private var creating = false
    @State private var draftName = ""
    @State private var byCreator = false

    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: Grid.gutter), GridItem(.flexible(), spacing: Grid.gutter)]
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                FloatingHeader(
                    title: "Playlists",
                    subtitle: summaries.isEmpty ? nil : "\(summaries.count)",
                    trailing: {
                        AnyView(
                            Button { draftName = ""; creating = true } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Label.onInverse)
                                    .frame(width: 34, height: 34)
                                    .background(Surface.inverse, in: Circle())
                            }
                            .accessibilityLabel("New playlist")
                        )
                    }
                )

                byCreatorRow

                if summaries.isEmpty {
                    empty
                } else {
                    LazyVGrid(columns: columns, spacing: Grid.gutter) {
                        ForEach(summaries) { summary in
                            Button {
                                Haptics.shared.tick()
                                open = summary.id
                            } label: {
                                PlaylistCard(
                                    summary: summary,
                                    items: state.coverItems(forPlaylist: summary.id ?? 0),
                                    loader: state.loader
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Grid.margin)
                }
            }
            .padding(.bottom, Grid.bottomInset)
        }
        .background(Surface.canvas)
        .ignoresSafeArea(edges: .bottom)
        .sheet(item: Binding(get: { open.map(Opened.init) }, set: { open = $0?.id })) { opened in
            PlaylistDetailView(playlistID: opened.id)
        }
        .sheet(isPresented: $byCreator) { CollectionsView() }
        .alert("New playlist", isPresented: $creating) {
            TextField("Name", text: $draftName)
            Button("Create") { create() }
            Button("Cancel", role: .cancel) {}
        }
        .task {
            reload()
            openForScreenshot()
        }
        .onChange(of: open) { _, value in if value == nil { reload() } }
    }

    private struct Opened: Identifiable { let id: Int64 }

    private var byCreatorRow: some View {
        Button { byCreator = true } label: {
            HStack {
                Image(systemName: "person.2")
                    .font(.system(size: 14))
                    .foregroundStyle(Label.secondary)
                Text("By creator")
                    .font(Type.body)
                    .foregroundStyle(Label.primary)
                Spacer()
                Text("\(state.authors.count)")
                    .font(Type.meta(10))
                    .foregroundStyle(Label.tertiary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Label.dim)
            }
            .padding(Space.base)
            .background(Surface.raised)
            .tileShape(.control, stroked: false)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Grid.margin)
        .padding(.bottom, Space.base)
    }

    private var empty: some View {
        VStack(spacing: Space.snug) {
            Text("No playlists yet")
                .font(Type.body)
                .foregroundStyle(Label.secondary)
            Text("A playlist is where a series lives — the ideas, and the videos behind them.")
                .font(Type.caption)
                .foregroundStyle(Label.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(Space.section)
    }

    private func reload() { summaries = state.playlists() }

    /// Opens a screen directly, for screenshot runs. DEBUG-only so it cannot ship.
    ///
    /// A sheet cannot be driven from a script, and a screenshot of a screen nobody can reach
    /// is not verification. This is the smallest hook that makes the two screens that matter
    /// actually checkable.
    private func openForScreenshot() {
        #if DEBUG
        guard let screen = UserDefaults.standard.string(forKey: "allimScreen") else { return }
        // The richest playlist, not the first: a screenshot of an empty one proves nothing.
        guard let target = summaries.max(by: { $0.ideaCount < $1.ideaCount }), let id = target.id else { return }
        if screen == "playlist" || screen == "idea" { open = id }
        #endif
    }

    private func create() {
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let made = state.createPlaylist(name: trimmed) {
            reload()
            open = made.id
        }
    }
}

private struct PlaylistCard: View {
    let summary: PlaylistSummary
    let items: [Item]
    let loader: ThumbnailLoader?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.snug) {
            ZStack {
                Surface.raised
                if let first = items.first {
                    ItemTile(item: first, loader: loader)
                } else {
                    Image(systemName: "rectangle.stack")
                        .font(.system(size: 26, weight: .light))
                        .foregroundStyle(Label.dim)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .tileShape(.cover)

            VStack(alignment: .leading, spacing: 1) {
                Text(summary.name)
                    .font(Type.bodyEmphasis)
                    .foregroundStyle(Label.primary)
                    .lineLimit(1)
                Text(summary.ideaCount == 1 ? "1 idea" : "\(summary.ideaCount) ideas")
                    .font(Type.meta(10))
                    .foregroundStyle(Label.tertiary)
            }
            .padding(.horizontal, Space.tight)
        }
        .padding(.bottom, Space.base)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(summary.name), \(summary.ideaCount) ideas")
    }
}
