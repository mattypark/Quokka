import SwiftUI
import QuokkaDesign
import QuokkaEngine
import QuokkaImaging

/// One saved thing, opened -- a Cosmos element page.
///
/// The picture at its own shape, who made it and where it came from, a way back to the
/// original, what was said in it if it has been transcribed, the playlists it is on with a
/// picker and a black Save pill to put it on another, and more from the same creator
/// underneath.
///
/// There is still only one stored image per item (600px), so the picture here is the grid's
/// thumbnail shown larger rather than a second, sharper derivative. The original is one tap
/// away for full resolution.
struct ItemDetailView: View {
    let itemID: Int64

    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var item: Item?
    @State private var transcript: Transcript?
    @State private var showsFullTranscript = false
    @State private var memberships: [Playlist] = []
    @State private var choices: [PlaylistCard.Model] = []
    @State private var target: Int64?
    @State private var savedTo: String?
    @State private var more: [Item] = []

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                if let item {
                    VStack(alignment: .leading, spacing: Space.loose) {
                        picture(item, width: proxy.size.width - Space.roomy * 2)
                        about(item)
                        if let transcript, transcript.isUsable { transcriptSection(transcript) }
                        saveRow
                        if !memberships.isEmpty { inPlaylists }
                        if !more.isEmpty { moreFromAuthor(item, width: proxy.size.width) }
                    }
                    .padding(.top, Space.tight)
                    .padding(.bottom, Space.chapter)
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { topControls }
        .background(Surface.canvas)
        .toolbar(.hidden, for: .navigationBar)
        .task(id: itemID) { load() }
    }

    // MARK: - Top

    private var topControls: some View {
        HStack {
            CircleButton(icon: "chevron.left", label: "Back") { dismiss() }
            Spacer()
            if let item, let url = URL(string: item.url), url.scheme?.hasPrefix("http") == true {
                Menu {
                    Button { openURL(url) } label: { SwiftUI.Label("Open original", systemImage: "arrow.up.right") }
                    Button {
                        UIPasteboard.general.url = url
                        Haptics.shared.saved()
                    } label: { SwiftUI.Label("Copy link", systemImage: "link") }
                    ShareLink(item: url) { SwiftUI.Label("Share", systemImage: "square.and.arrow.up") }
                } label: {
                    CircleGlyph(icon: "ellipsis")
                }
                .accessibilityLabel("More")
            }
        }
        .padding(.horizontal, Space.roomy)
        .padding(.vertical, Space.tight)
        .background(Surface.canvas)
    }

    // MARK: - Picture

    private func picture(_ item: Item, width: CGFloat) -> some View {
        // Clamped like the grid, so a very tall reel does not push everything else off the
        // first screen.
        let ratio = min(max(item.aspectRatio ?? 0.8, 0.5), 2.0)
        return ItemTile(item: item, loader: state.loader)
            .frame(width: width, height: width / ratio)
            .frame(maxWidth: .infinity)
    }

    // MARK: - About

    private func about(_ item: Item) -> some View {
        VStack(alignment: .leading, spacing: Space.base) {
            HStack(alignment: .center, spacing: Space.base) {
                VStack(alignment: .leading, spacing: 2) {
                    if let author = item.author {
                        NavigationLink(value: Route.creator(author)) {
                            Text(author)
                                .font(Type.bodyEmphasis)
                                .foregroundStyle(Label.primary)
                        }
                        .buttonStyle(.plain)
                    }
                    Text("\(item.platform.displayName) · \(item.savedAt.formatted(.dateTime.day().month(.abbreviated).year()))")
                        .font(Type.caption)
                        .foregroundStyle(Label.secondary)
                }
                Spacer(minLength: 0)
                if let url = URL(string: item.url), url.scheme?.hasPrefix("http") == true {
                    Button { openURL(url) } label: {
                        OutlinePill(title: "Open", icon: "arrow.up.right")
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityLabel("Open the original post")
                }
            }

            if let title = item.title, !title.isEmpty, title != item.url {
                Text(title)
                    .font(Type.body)
                    .foregroundStyle(Label.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let caption = item.caption, !caption.isEmpty {
                Text(caption)
                    .font(Type.body)
                    .foregroundStyle(Label.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !tags(item).isEmpty {
                FlowTags(tags: tags(item))
            }
        }
        .padding(.horizontal, Space.roomy)
    }

    /// Tags are a JSON array in a text column, written by Claude over the MCP.
    private func tags(_ item: Item) -> [String] {
        guard let raw = item.tags, let data = raw.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }

    // MARK: - Transcript

    private func transcriptSection(_ transcript: Transcript) -> some View {
        VStack(alignment: .leading, spacing: Space.snug) {
            Text("What was said")
                .font(Type.caption)
                .foregroundStyle(Label.secondary)
            Text(transcript.text)
                .font(Type.body)
                .foregroundStyle(Label.primary)
                .lineLimit(showsFullTranscript ? nil : 6)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            Button(showsFullTranscript ? "Show less" : "Show all") {
                withAnimation(Motion.respecting(.easeOut(duration: 0.2))) { showsFullTranscript.toggle() }
            }
            .font(Type.control)
            .foregroundStyle(Label.primary)
        }
        .padding(.horizontal, Space.roomy)
    }

    // MARK: - Save to a playlist

    /// A picker beside a black Save pill, which is Cosmos's cluster dropdown and Save button.
    private var saveRow: some View {
        HStack(spacing: Space.snug) {
            Menu {
                ForEach(choices) { choice in
                    Button(choice.name) { target = choice.id }
                }
                if choices.isEmpty {
                    Text("No playlists yet")
                }
            } label: {
                HStack(spacing: Space.snug) {
                    Image(systemName: "rectangle.stack")
                        .font(.system(size: 13, weight: .medium))
                    Text(choices.first(where: { $0.id == target })?.name ?? "Choose a playlist")
                        .font(Type.control)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(Label.primary)
                .padding(.horizontal, Space.base)
                .frame(height: Control.pillHeight)
                .background(Surface.field, in: Capsule())
                .overlay(Capsule().stroke(Surface.hairlineStrong, lineWidth: Stroke.thin))
            }

            Button(action: save) {
                FilledPill(title: savedTo == nil ? "Save" : "Saved", icon: savedTo == nil ? nil : "checkmark")
                    .frame(width: 104)
            }
            .buttonStyle(PressStyle())
            .disabled(target == nil)
            .opacity(target == nil ? 0.4 : 1)
        }
        .padding(.horizontal, Space.roomy)
    }

    private var inPlaylists: some View {
        VStack(alignment: .leading, spacing: Space.snug) {
            Text(memberships.count == 1 ? "In 1 playlist" : "In \(memberships.count) playlists")
                .font(Type.caption)
                .foregroundStyle(Label.secondary)
            VStack(spacing: 0) {
                ForEach(memberships) { playlist in
                    if let id = playlist.id {
                        NavigationLink(value: Route.playlist(id)) {
                            PlaylistRow(
                                name: playlist.name,
                                count: choices.first(where: { $0.id == id })?.count,
                                cover: state.playlistCover(id, limit: 1),
                                loader: state.loader)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, Space.roomy)
    }

    // MARK: - More from the creator

    private func moreFromAuthor(_ item: Item, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: Space.base) {
            Text("More from \(item.author ?? "this creator")")
                .font(Type.title(17))
                .foregroundStyle(Label.primary)
                .padding(.horizontal, Space.roomy)
            MasonryGrid(
                items: more,
                columns: Grid.columns,
                spacing: Grid.gutter,
                width: width - Grid.margin * 2
            ) { other, _ in
                TileLink(item: other, loader: state.loader)
            }
            .padding(.horizontal, Grid.margin)
        }
        .padding(.top, Space.base)
    }

    // MARK: - Work

    private func load() {
        item = state.item(id: itemID)
        transcript = state.transcript(forItem: itemID)
        memberships = state.playlists(containing: itemID)
        choices = state.playlistCards()
        if target == nil { target = choices.first(where: { card in !memberships.contains { $0.id == card.id } })?.id }
        if let author = item?.author, let page = state.page(author: author) {
            more = Array(page.items.filter { $0.id != itemID }.prefix(12))
        } else {
            more = []
        }
    }

    private func save() {
        guard let target, let name = choices.first(where: { $0.id == target })?.name else { return }
        state.addToPlaylist(target, itemIDs: [itemID])
        Haptics.shared.saved()
        savedTo = name
        memberships = state.playlists(containing: itemID)
        choices = state.playlistCards()
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            savedTo = nil
        }
    }
}

/// A playlist as a row: small cover, name, count -- Cosmos's "Saved by" list.
private struct PlaylistRow: View {
    let name: String
    let count: Int?
    let cover: [Item]
    let loader: ThumbnailLoader?

    var body: some View {
        HStack(spacing: Space.base) {
            Mosaic(items: cover, loader: loader, monogram: Mosaic.monogram(for: name))
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(Type.bodyEmphasis)
                    .foregroundStyle(Label.primary)
                if let count {
                    Text(count == 1 ? "1 save" : "\(count) saves")
                        .font(Type.caption)
                        .foregroundStyle(Label.secondary)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Label.dim)
        }
        .padding(.vertical, Space.snug)
        .contentShape(Rectangle())
    }
}

/// Tags as small outlined pills that wrap onto as many lines as they need.
private struct FlowTags: View {
    let tags: [String]

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(Type.caption)
                    .foregroundStyle(Label.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .overlay(Capsule().stroke(Surface.hairlineStrong, lineWidth: Stroke.thin))
            }
        }
    }
}

/// Lays children left to right and wraps. The system has no wrapping stack.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var line: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += line + spacing
                line = 0
            }
            x += size.width + spacing
            line = max(line, size.height)
        }
        return CGSize(width: width == .infinity ? x : width, height: y + line)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var line: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += line + spacing
                line = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            line = max(line, size.height)
        }
    }
}
