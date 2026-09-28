import SwiftUI
import QuokkaDesign
import QuokkaEngine
import QuokkaImaging

/// Creators, as covers rather than as a list.
///
/// Each author gets a mosaic built from their own saves: you recognise a creator by what is
/// in the cover long before you read the name. The grouping is by author because that is what
/// the data actually contains -- an Instagram import lands thousands of items each carrying
/// the handle that made them. No inference, and a category that is true by construction.
struct CreatorsPane: View {
    @Environment(AppState.self) private var state

    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: Grid.gutter), GridItem(.flexible(), spacing: Grid.gutter)]
    }

    var body: some View {
        if state.authors.isEmpty {
            EmptyNote(
                title: "Nothing to group yet",
                detail: "Creators appear here on their own, from whoever made the things you save.")
        } else {
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: columns, alignment: .leading, spacing: Space.loose) {
                    ForEach(state.authors) { author in
                        NavigationLink(value: Route.creator(author.name)) {
                            CreatorCard(
                                author: author,
                                items: state.coverItems(for: author.name),
                                loader: state.loader)
                        }
                        .buttonStyle(PressStyle())
                    }
                }
                .padding(.horizontal, Grid.margin)
                .padding(.top, Space.tight)
                .padding(.bottom, Grid.bottomInset)
            }
        }
    }
}

/// A square cover at the cover radius, the name under it and the count under that -- a
/// Cosmos cluster card.
private struct CreatorCard: View {
    let author: AuthorGroup
    let items: [Item]
    let loader: ThumbnailLoader?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.snug) {
            Mosaic(items: items, loader: loader, monogram: Mosaic.monogram(for: author.name))
                .aspectRatio(1, contentMode: .fit)
                .tileShape(.cover)

            VStack(alignment: .leading, spacing: 1) {
                Text(author.name)
                    .font(Type.bodyEmphasis)
                    .foregroundStyle(Label.primary)
                    .lineLimit(1)
                Text(author.count == 1 ? "1 save" : "\(author.count) saves")
                    .font(Type.caption)
                    .foregroundStyle(Label.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(author.name), \(author.count) saved")
    }
}

/// A 2x2 of a group's own pictures. One picture fills it; none gets a monogram.
///
/// Shared by creator and playlist covers, which are the same object with different contents.
struct Mosaic: View {
    let items: [Item]
    let loader: ThumbnailLoader?
    var monogram = ""

    /// Only items that actually have a picture. A mosaic of blank cards says nothing about
    /// what is inside, which is the one job a cover has.
    private var usable: [Item] { items.filter { $0.thumbnailState == .stored } }

    var body: some View {
        Surface.field.overlay {
            switch usable.count {
            case 0:
                // Every save here is from a platform that publishes no image -- Instagram
                // groups usually are. A monogram is a deliberate cover rather than a grey
                // square that reads as a loading failure.
                Text(monogram)
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(Label.dim)
            case 1:
                MosaicTile(item: usable[0], loader: loader)
            default:
                SwiftUI.Grid(horizontalSpacing: 1, verticalSpacing: 1) {
                    GridRow {
                        MosaicTile(item: usable[0], loader: loader)
                        MosaicTile(item: usable[1 % usable.count], loader: loader)
                    }
                    GridRow {
                        MosaicTile(item: usable[2 % usable.count], loader: loader)
                        MosaicTile(item: usable[3 % usable.count], loader: loader)
                    }
                }
            }
        }
        .clipped()
    }

    /// Two letters, from a handle like "kitchen.studio", "r/design" or "nasa".
    ///
    /// A multi-part handle takes one letter from each of the first two parts; a single word
    /// takes its first two, or "nasa" renders as a lone "N" beside "BA".
    static func monogram(for name: String) -> String {
        let parts = name
            .split(whereSeparator: { ".-_/ ".contains($0) })
            .filter { !$0.isEmpty }
        if parts.count >= 2 {
            return String(parts.prefix(2).compactMap(\.first)).uppercased()
        }
        return String((parts.first ?? "").prefix(2)).uppercased()
    }
}

/// One quadrant of a cover. Deliberately not `ItemTile`: no fallback text -- it is texture,
/// and a cover made of readable cards would compete with its own label.
private struct MosaicTile: View {
    let item: Item
    let loader: ThumbnailLoader?

    @State private var image: UIImage?

    private var ground: Color {
        guard let packed = item.averageColor else { return Surface.raised }
        let (r, g, b) = AverageColor.components(packed)
        return Color(.sRGB, red: r, green: g, blue: b)
    }

    var body: some View {
        ground
            .overlay {
                if let image {
                    Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
                }
            }
            .clipped()
        .task(id: item.id) {
            guard let loader, let id = item.id, item.thumbnailState == .stored else { return }
            image = await loader.image(for: id)
        }
    }
}

/// One creator, opened.
///
/// Pages its own items rather than filtering the shared library, so going back lands on the
/// home grid exactly as it was left.
struct CreatorView: View {
    let author: String

    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss

    @State private var items: [Item] = []
    @State private var cursor: ItemCursor?
    @State private var count: Int?

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: Space.loose) {
                    VStack(spacing: Space.tight) {
                        Text(author)
                            .font(Type.screenTitle)
                            .foregroundStyle(Label.primary)
                            .multilineTextAlignment(.center)
                        if let count {
                            Text(count == 1 ? "1 save" : "\(count) saves")
                                .font(Type.nav)
                                .foregroundStyle(Label.secondary)
                        }
                    }
                    .padding(.horizontal, Space.chapter)

                    MasonryGrid(
                        items: items,
                        columns: Grid.columns,
                        spacing: Grid.gutter,
                        width: proxy.size.width - Grid.margin * 2
                    ) { item, _ in
                        TileLink(item: item, loader: state.loader)
                            .onAppear { if item.id == items.last?.id { loadMore() } }
                    }
                    .padding(.horizontal, Grid.margin)
                }
                .padding(.top, Space.tight)
                .padding(.bottom, Grid.bottomInset)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                CircleButton(icon: "chevron.left", label: "Back") { dismiss() }
                Spacer()
            }
            .padding(.horizontal, Space.roomy)
            .padding(.vertical, Space.tight)
            .background(Surface.canvas)
        }
        .background(Surface.canvas)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            guard items.isEmpty else { return }
            count = state.authors.first(where: { $0.name == author })?.count
            loadMore()
        }
    }

    private func loadMore() {
        guard items.isEmpty || cursor != nil else { return }
        guard let page = state.page(author: author, after: cursor) else { return }
        items.append(contentsOf: page.items)
        cursor = page.cursor
    }
}
