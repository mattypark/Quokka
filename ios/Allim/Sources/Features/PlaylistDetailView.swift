import SwiftUI
import AllimDesign
import AllimEngine
import AllimImaging

/// One playlist, opened.
struct PlaylistDetailView: View {
    let playlistID: Int64

    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss

    @State private var playlist: Playlist?
    @State private var ideas: [Idea] = []
    @State private var pane: Pane = .ideas
    @State private var openIdea: Int64?
    @State private var naming = false
    @State private var draftName = ""

    private enum Pane: Hashable { case ideas, media }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: Space.base) {
                    header
                    cover
                    addRow
                    SegmentedTabs(
                        options: [(.ideas, "Ideas"), (.media, "Media")],
                        selection: $pane
                    )
                    .padding(.horizontal, Space.roomy)
                    .padding(.top, Space.tight)

                    switch pane {
                    case .ideas: ideaList
                    case .media: media
                    }
                }
                .padding(.bottom, Grid.bottomInset)
            }
            .background(Surface.canvas)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "chevron.left") }
                        .accessibilityLabel("Back")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Rename") { draftName = playlist?.name ?? ""; naming = true }
                        Button("Delete", role: .destructive) { deletePlaylist() }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
            .toolbarBackground(Surface.canvas, for: .navigationBar)
        }
        .tint(Label.primary)
        .sheet(item: Binding(get: { openIdea.map(Opened.init) }, set: { openIdea = $0?.id })) { opened in
            IdeaDetailView(ideaID: opened.id)
        }
        .alert("Rename playlist", isPresented: $naming) {
            TextField("Name", text: $draftName)
            Button("Save") { rename() }
            Button("Cancel", role: .cancel) {}
        }
        .task {
            load()
            #if DEBUG
            // Continues the deep link one level further, into the idea itself.
            if UserDefaults.standard.string(forKey: "allimScreen") == "idea" {
                openIdea = ideas.first(where: { $0.hasScript })?.id ?? ideas.first?.id
            }
            #endif
        }
    }

    private struct Opened: Identifiable { let id: Int64 }

    // MARK: - Pieces

    private var header: some View {
        VStack(spacing: 2) {
            Text(playlist?.name ?? "")
                .font(Type.bodyEmphasis)
                .foregroundStyle(Label.primary)
            Text(playlist?.subtitle(ideaCount: ideas.count) ?? "")
                .font(Type.caption)
                .foregroundStyle(Label.tertiary)
        }
    }

    private var cover: some View {
        PlaylistCover(items: state.coverItems(forPlaylist: playlistID), loader: state.loader)
            .frame(maxWidth: .infinity)
            .frame(height: 260)
            .padding(.horizontal, Space.section)
    }

    /// Sort, Add, edit -- on one line, with Add taking the width.
    ///
    /// The imbalance is the design: Add is the verb this screen exists for, and the other two
    /// are adjustments to what Add produced. Three equal buttons would say they matter equally.
    private var addRow: some View {
        HStack(spacing: Space.base) {
            circleControl("arrow.up.arrow.down", label: "Sort") {}

            Button(action: newIdea) {
                HStack(spacing: Space.snug) {
                    Image(systemName: "plus").font(.system(size: 15, weight: .medium))
                    Text("Add").font(Type.bodyEmphasis)
                }
                .foregroundStyle(Label.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Surface.elevated, in: Capsule())
            }

            circleControl("pencil", label: "Edit") { draftName = playlist?.name ?? ""; naming = true }
        }
        .padding(.horizontal, Space.roomy)
    }

    private func circleControl(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(Label.secondary)
                .frame(width: 50, height: 50)
                .background(Surface.elevated, in: Circle())
        }
        .accessibilityLabel(label)
    }

    private var ideaList: some View {
        Group {
            if ideas.isEmpty {
                VStack(spacing: Space.snug) {
                    Text("No ideas yet")
                        .font(Type.body)
                        .foregroundStyle(Label.secondary)
                    Text("Add one and start writing.")
                        .font(Type.caption)
                        .foregroundStyle(Label.tertiary)
                }
                .padding(.vertical, Space.section)
            } else {
                LazyVStack(spacing: Space.snug) {
                    ForEach(ideas) { idea in
                        IdeaRow(idea: idea) { openIdea = idea.id } onDelete: { delete(idea) }
                    }
                }
                .padding(.horizontal, Space.roomy)
                .padding(.top, Space.snug)
            }
        }
    }

    private var media: some View {
        let items = state.mediaItems(forPlaylist: playlistID)
        return Group {
            if items.isEmpty {
                Text("Nothing saved into this playlist yet.")
                    .font(Type.caption)
                    .foregroundStyle(Label.tertiary)
                    .padding(.vertical, Space.section)
            } else {
                GeometryReader { proxy in
                    MasonryGrid(
                        items: items,
                        columns: Grid.columns,
                        spacing: Grid.gutter,
                        width: proxy.size.width - Grid.margin * 2
                    ) { item, _ in
                        ItemTile(item: item, loader: state.loader)
                    }
                    .padding(.horizontal, Grid.margin)
                }
                .frame(height: 900)
            }
        }
    }

    // MARK: - Work

    private func load() {
        playlist = state.playlist(id: playlistID)
        ideas = state.ideas(inPlaylist: playlistID)
    }

    private func newIdea() {
        Haptics.shared.tick()
        if let created = state.createIdea(title: "Untitled idea", playlistID: playlistID) {
            load()
            openIdea = created.id
        }
    }

    private func rename() {
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        state.renamePlaylist(id: playlistID, to: trimmed)
        load()
    }

    private func delete(_ idea: Idea) {
        guard let id = idea.id else { return }
        state.deleteIdea(id: id)
        load()
    }

    private func deletePlaylist() {
        state.deletePlaylist(id: playlistID)
        dismiss()
    }
}

/// One row in a playlist's idea list.
private struct IdeaRow: View {
    let idea: Idea
    let onOpen: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .top, spacing: Space.base) {
                Image(systemName: "music.note")
                    .font(.system(size: 13))
                    .foregroundStyle(Label.tertiary)
                    .frame(width: 22)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 3) {
                    Text(idea.title)
                        .font(Type.bodyEmphasis)
                        .foregroundStyle(Label.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    Text(idea.modifiedDescription())
                        .font(Type.caption)
                        .foregroundStyle(Label.dim)
                }

                Spacer(minLength: 0)

                Menu {
                    Button("Delete", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15))
                        .foregroundStyle(Label.dim)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
            }
            .padding(Space.base)
            .background(Surface.raised)
            .tileShape(.control, stroked: false)
        }
        .buttonStyle(.plain)
    }
}

/// A playlist's cover: one item fills it, several make a mosaic, none gets a monogram.
private struct PlaylistCover: View {
    let items: [Item]
    let loader: ThumbnailLoader?

    var body: some View {
        ZStack {
            Surface.raised
            if items.isEmpty {
                Image(systemName: "rectangle.stack")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(Label.dim)
            } else {
                ItemTile(item: items[0], loader: loader)
            }
        }
        .tileShape(.cover)
    }
}
