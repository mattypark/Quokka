import SwiftUI
import QuokkaDesign
import QuokkaEngine
import QuokkaImaging

/// One playlist, opened -- a Cosmos cluster.
///
/// Grey back circle, a centered title with its count under it, the saves as a two-column
/// masonry, and one floating pill at the bottom holding everything you can do to the
/// playlist: Organize, Add, Share, More.
struct PlaylistDetailView: View {
    let playlistID: Int64

    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss

    @State private var playlist: Playlist?
    @State private var items: [Item] = []
    @State private var ideas: [Idea] = []
    @State private var pane: Pane = .saves
    @State private var filter = ""
    @State private var searching = false
    @State private var organizing = false
    @State private var selected: Set<Int64> = []
    @State private var adding = false
    @State private var openIdea: Int64?
    @State private var naming = false
    @State private var draftName = ""
    @State private var copiedPrompt = false

    private enum Pane: Hashable { case saves, ideas }

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: Space.loose) {
                    header
                    if searching { searchField }
                    summary
                    UnderlineTabs(
                        options: [(.saves, "Saves", items.count), (.ideas, "Ideas", ideas.count)],
                        selection: $pane
                    )
                    switch pane {
                    case .saves: saves(width: proxy.size.width)
                    case .ideas: ideaList
                    }
                }
                .padding(.top, Space.tight)
                .padding(.bottom, 120)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { topControls }
        .overlay(alignment: .bottom) { actionPill.padding(.bottom, Space.tight) }
        .background(Surface.canvas)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: Binding(get: { openIdea.map(Opened.init) }, set: { openIdea = $0?.id })) { opened in
            IdeaDetailView(ideaID: opened.id)
        }
        .sheet(isPresented: $adding, onDismiss: load) {
            AddSavesSheet(playlistID: playlistID, existing: Set(items.compactMap(\.id)))
        }
        .alert("Rename playlist", isPresented: $naming) {
            TextField("Name", text: $draftName)
            Button("Save") { rename() }
            Button("Cancel", role: .cancel) {}
        }
        .onChange(of: openIdea) { _, value in if value == nil { load() } }
        .task {
            load()
            #if DEBUG
            // Continues the deep link one level further, into the idea itself.
            if UserDefaults.standard.string(forKey: "quokkaScreen") == "idea" {
                openIdea = ideas.first(where: { $0.hasScript })?.id ?? ideas.first?.id
            }
            #endif
        }
    }

    private struct Opened: Identifiable { let id: Int64 }

    // MARK: - Header

    private var topControls: some View {
        HStack {
            CircleButton(icon: "chevron.left", label: "Back") { dismiss() }
            Spacer()
            CircleButton(icon: searching ? "xmark" : "magnifyingglass", label: searching ? "Close search" : "Search this playlist") {
                withAnimation(Motion.respecting(.easeOut(duration: 0.2))) {
                    searching.toggle()
                    if !searching { filter = "" }
                }
            }
        }
        .padding(.horizontal, Space.roomy)
        .padding(.vertical, Space.tight)
        .background(Surface.canvas)
    }

    private var header: some View {
        VStack(spacing: Space.tight) {
            Text(playlist?.name ?? "")
                .font(Type.screenTitle)
                .foregroundStyle(Label.primary)
                .multilineTextAlignment(.center)
            HStack(spacing: 5) {
                Text(items.count == 1 ? "1 save" : "\(items.count) saves")
                Text("·")
                Text(ideas.count == 1 ? "1 idea" : "\(ideas.count) ideas")
                Text("·")
                // Everything in Quokka is private -- there is nobody to share it with -- and
                // the lock says so where Cosmos marks a private cluster.
                Image(systemName: "lock.fill").font(.system(size: 11))
            }
            .font(Type.nav)
            .foregroundStyle(Label.secondary)
        }
        .padding(.horizontal, Space.section)
    }

    private var searchField: some View {
        HStack(spacing: Space.snug) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Label.secondary)
            TextField("Search this playlist", text: $filter)
                .font(Type.field)
                .submitLabel(.search)
        }
        .padding(.horizontal, Space.roomy)
        .frame(height: 44)
        .background(Surface.field, in: Capsule())
        .overlay(Capsule().stroke(Surface.hairlineStrong, lineWidth: Stroke.thin))
        .padding(.horizontal, Space.roomy)
    }

    // MARK: - Summary

    /// Three states, and they are different things: never summarised, summarised before the
    /// latest saves, and current. `summary` is never `note` -- one is a model's digest, the
    /// other is what the person wrote.
    @ViewBuilder
    private var summary: some View {
        if let text = playlist?.summary, !text.isEmpty {
            VStack(alignment: .leading, spacing: Space.snug) {
                HStack(spacing: Space.tight) {
                    Text("Summary")
                        .font(Type.caption)
                        .foregroundStyle(Label.secondary)
                    if playlist?.summaryIsStale == true {
                        Text("· written before your latest saves")
                            .font(Type.caption)
                            .foregroundStyle(Label.secondary)
                    }
                }
                Text(text)
                    .font(Type.body)
                    .foregroundStyle(Label.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Space.roomy)
        } else if !items.isEmpty {
            // The work happens in Claude Code on the Mac and lands on the next launch, so this
            // is an instruction and a copy button, never a spinner that promises it is instant.
            HStack(alignment: .top, spacing: Space.base) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("No summary yet")
                        .font(Type.bodyEmphasis)
                        .foregroundStyle(Label.primary)
                    Text(state.mirrorsToClaude
                         ? "Ask Claude Code on your Mac to summarise it. It shows up here the next time you open Quokka."
                         : "Turn on “Let Claude read your library” in Settings, then ask Claude Code on your Mac.")
                        .font(Type.caption)
                        .foregroundStyle(Label.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button(action: copyPrompt) {
                    OutlinePill(title: copiedPrompt ? "Copied" : "Copy ask", icon: copiedPrompt ? "checkmark" : nil)
                }
                .buttonStyle(PressStyle())
            }
            .padding(Space.base)
            .background(Surface.field)
            .tileShape(.control, stroked: true)
            .padding(.horizontal, Space.roomy)
        }
    }

    // MARK: - Panes

    private var visibleItems: [Item] {
        let query = filter.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return items }
        return items.filter { item in
            [item.title, item.author, item.caption, item.url]
                .compactMap { $0?.lowercased() }
                .contains { $0.contains(query) }
        }
    }

    @ViewBuilder
    private func saves(width: CGFloat) -> some View {
        if items.isEmpty {
            EmptyNote(title: "Nothing in here yet", detail: "Tap Add to drop saves into this playlist.")
        } else {
            MasonryGrid(
                items: visibleItems,
                columns: Grid.columns,
                spacing: Grid.gutter,
                width: width - Grid.margin * 2
            ) { item, _ in
                if organizing, let id = item.id {
                    Button { toggle(id) } label: {
                        ItemTile(item: item, loader: state.loader)
                            .overlay(alignment: .topTrailing) { SelectionMark(on: selected.contains(id)) }
                            .opacity(selected.contains(id) ? 0.7 : 1)
                    }
                    .buttonStyle(.plain)
                } else {
                    TileLink(item: item, loader: state.loader)
                }
            }
            .padding(.horizontal, Grid.margin)
        }
    }

    private var ideaList: some View {
        VStack(spacing: 0) {
            Button(action: newIdea) {
                HStack(spacing: Space.base) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 22)
                    Text("New idea")
                        .font(Type.bodyEmphasis)
                    Spacer()
                }
                .foregroundStyle(Label.primary)
                .padding(.vertical, Space.base)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .overlay(alignment: .bottom) { Rectangle().fill(Surface.hairline).frame(height: Stroke.thin) }

            ForEach(ideas) { idea in
                IdeaRow(idea: idea) { openIdea = idea.id } onDelete: { delete(idea) }
            }
        }
        .padding(.horizontal, Space.roomy)
    }

    // MARK: - Action pill

    /// Organize, Add, Share, More -- or, while organizing, what to do with the selection.
    private var actionPill: some View {
        HStack(spacing: 0) {
            if organizing {
                pillButton("Done", icon: "checkmark") {
                    organizing = false
                    selected = []
                }
                pillButton(selected.isEmpty ? "Remove" : "Remove \(selected.count)", icon: "minus.circle") {
                    removeSelected()
                }
                .disabled(selected.isEmpty)
                .opacity(selected.isEmpty ? 0.4 : 1)
            } else {
                pillButton("Organize", icon: "square.stack") {
                    pane = .saves
                    organizing = true
                }
                .disabled(items.isEmpty)
                pillButton("Add", icon: "plus") { adding = true }
                ShareLink(item: shareText) {
                    pillLabel("Share", icon: "square.and.arrow.up")
                }
                .buttonStyle(PressStyle())
                .disabled(items.isEmpty)
                Menu {
                    Button("Rename") { draftName = playlist?.name ?? ""; naming = true }
                    Button("New idea") { newIdea() }
                    Button("Delete playlist", role: .destructive) { deletePlaylist() }
                } label: {
                    pillLabel("More", icon: "ellipsis")
                }
            }
        }
        .padding(.horizontal, Space.snug)
        .background(
            Capsule()
                .fill(Surface.canvas)
                .overlay(Capsule().stroke(Surface.hairline, lineWidth: Stroke.thin))
                .shadow(color: .black.opacity(0.08), radius: 16, y: 4)
        )
        .animation(Motion.respecting(.easeOut(duration: 0.18)), value: organizing)
    }

    private func pillButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.shared.tick()
            action()
        } label: {
            pillLabel(title, icon: icon)
        }
        .buttonStyle(PressStyle())
    }

    private func pillLabel(_ title: String, icon: String) -> some View {
        VStack(spacing: 3) {
            // A fixed box, so an ellipsis and a share arrow put their labels on one baseline.
            Image(systemName: icon)
                .font(.system(size: 18, weight: .regular))
                .frame(height: 24)
            Text(title).font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(Label.primary)
        .frame(width: 70, height: 56)
        .contentShape(Rectangle())
    }

    private var shareText: String {
        items.map(\.url).filter { !$0.hasPrefix("quokka://") }.joined(separator: "\n")
    }

    // MARK: - Work

    private func load() {
        playlist = state.playlist(id: playlistID)
        items = state.playlistItems(playlistID)
        ideas = state.ideas(inPlaylist: playlistID)
    }

    private func toggle(_ id: Int64) {
        Haptics.shared.tick()
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }

    private func removeSelected() {
        state.removeFromPlaylist(playlistID, itemIDs: Array(selected))
        selected = []
        organizing = false
        load()
    }

    private func newIdea() {
        Haptics.shared.tick()
        if let created = state.createIdea(title: "Untitled idea", playlistID: playlistID) {
            load()
            pane = .ideas
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

    private func copyPrompt() {
        UIPasteboard.general.string = "Summarise my Quokka playlist \"\(playlist?.name ?? "")\""
        Haptics.shared.saved()
        copiedPrompt = true
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            copiedPrompt = false
        }
    }
}

/// The round check on a tile while organizing.
struct SelectionMark: View {
    let on: Bool

    var body: some View {
        ZStack {
            Circle().fill(on ? Surface.inverse : Color.white.opacity(0.85))
            Circle().stroke(on ? Color.clear : Surface.hairlineStrong, lineWidth: Stroke.regular)
            if on {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Label.onInverse)
            }
        }
        .frame(width: 24, height: 24)
        .padding(Space.snug)
        .accessibilityHidden(true)
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
                VStack(alignment: .leading, spacing: 3) {
                    Text(idea.title)
                        .font(Type.bodyEmphasis)
                        .foregroundStyle(Label.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    Text(idea.modifiedDescription())
                        .font(Type.caption)
                        .foregroundStyle(Label.secondary)
                }

                Spacer(minLength: 0)

                Menu {
                    Button("Delete", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15))
                        .foregroundStyle(Label.secondary)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
            }
            .padding(.vertical, Space.base)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) { Rectangle().fill(Surface.hairline).frame(height: Stroke.thin) }
    }
}

/// Picking saves to drop into a playlist.
///
/// The library at three columns, tap to select, one button to commit -- the whole of it, with
/// the count on the button so it is clear what will happen before it does.
private struct AddSavesSheet: View {
    let playlistID: Int64
    let existing: Set<Int64>

    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<Int64> = []

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ScrollView(showsIndicators: false) {
                    MasonryGrid(
                        items: state.items,
                        columns: Grid.columnsWide,
                        spacing: Space.snug,
                        width: proxy.size.width - Grid.margin * 2
                    ) { item, _ in
                        let id = item.id ?? -1
                        let already = existing.contains(id)
                        Button {
                            guard !already else { return }
                            Haptics.shared.tick()
                            if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
                        } label: {
                            ItemTile(item: item, loader: state.loader)
                                .overlay(alignment: .topTrailing) {
                                    SelectionMark(on: already || selected.contains(id))
                                }
                                .opacity(already ? 0.4 : 1)
                        }
                        .buttonStyle(.plain)
                        .onAppear { if item.id == state.items.last?.id { state.loadMore() } }
                    }
                    .padding(.horizontal, Grid.margin)
                    .padding(.bottom, Space.section)
                }
            }
            .background(Surface.canvas)
            .navigationTitle("Add saves")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Surface.canvas, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.font(Type.control)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(selected.isEmpty ? "Add" : "Add \(selected.count)") {
                        state.addToPlaylist(playlistID, itemIDs: Array(selected))
                        Haptics.shared.saved()
                        dismiss()
                    }
                    .font(Type.control)
                    .disabled(selected.isEmpty)
                }
            }
        }
        .tint(Label.primary)
    }
}
