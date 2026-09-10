import SwiftUI
import AllimDesign
import AllimEngine
import AllimImaging

/// Collections, as covers rather than as a list.
///
/// Each author gets a mosaic built from their own saves, which is the whole idea: you recognise
/// a collection by what is in it long before you read its name. A list of names with counts
/// would be the same data and a fraction of the use.
///
/// The grouping is by author because that is what the data actually contains -- an Instagram
/// import lands thousands of items each carrying the handle that made them. No inference, no
/// AI, and a category that is true by construction.
struct CollectionsView: View {
    @Environment(AppState.self) private var state
    @State private var opened: String?

    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: Grid.gutter), GridItem(.flexible(), spacing: Grid.gutter)]
    }

    var body: some View {
        Group {
            if state.authors.isEmpty {
                empty
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        FloatingHeader(
                            title: "Collections",
                            subtitle: "\(state.authors.count) creators",
                            trailing: nil
                        )

                        LazyVGrid(columns: columns, spacing: Grid.gutter) {
                            ForEach(state.authors) { author in
                                Button {
                                    Haptics.shared.tick()
                                    opened = author.name
                                } label: {
                                    CollectionCover(
                                        author: author,
                                        items: state.coverItems(for: author.name),
                                        loader: state.loader
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, Grid.margin)
                    }
                    .padding(.bottom, Grid.bottomInset)
                }
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .background(Surface.canvas)
        .sheet(item: Binding(get: { opened.map(Opened.init) }, set: { opened = $0?.name })) { item in
            CollectionDetail(author: item.name)
        }
    }

    private struct Opened: Identifiable {
        let name: String
        var id: String { name }
    }

    private var empty: some View {
        VStack(spacing: Space.base) {
            Text("Nothing to group yet")
                .font(Type.title(20))
                .foregroundStyle(Label.primary)
            Text("Collections build themselves from whoever made the things you save.")
                .font(Type.body)
                .foregroundStyle(Label.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(Space.section)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// A 2x2 mosaic of the collection's own contents.
private struct CollectionCover: View {
    let author: AuthorGroup
    let items: [Item]
    let loader: ThumbnailLoader?

    /// Only items that actually have a picture. A mosaic of blank cards says nothing about
    /// what is inside, which is the one job a cover has.
    private var usableItems: [Item] {
        items.filter { $0.thumbnailState == .stored }
    }

    /// Two letters, from a handle like "kitchen.studio", "r/design" or "nasa".
    ///
    /// A multi-part handle takes one letter from each of the first two parts; a single word
    /// takes its first two. Without that second case "nasa" renders as a lone "N" next to
    /// "BA" and the grid looks inconsistent rather than considered.
    private var monogram: String {
        let parts = author.name
            .split(whereSeparator: { ".-_/ ".contains($0) })
            .filter { !$0.isEmpty }

        if parts.count >= 2 {
            return String(parts.prefix(2).compactMap(\.first)).uppercased()
        }
        return String((parts.first ?? "").prefix(2)).uppercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.snug) {
            ZStack {
                Surface.raised
                // Four quadrants, filled with whatever exists. One item fills the whole cover,
                // which reads better than one tile floating in three empty ones.
                switch usableItems.count {
                case 0:
                    // Every save here is from a platform that publishes no image -- Instagram
                    // collections are usually entirely this. A monogram is a deliberate cover
                    // rather than a grey square that reads as a loading failure.
                    Text(monogram)
                        .font(Type.title(46))
                        .foregroundStyle(Label.dim)
                case 1:
                    tile(usableItems[0])
                default:
                    Grid(horizontalSpacing: 1, verticalSpacing: 1) {
                        GridRow {
                            tile(usableItems[0])
                            tile(usableItems[1 % usableItems.count])
                        }
                        GridRow {
                            tile(usableItems[2 % usableItems.count])
                            tile(usableItems[3 % usableItems.count])
                        }
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .stroke(Surface.hairline, lineWidth: Stroke.thin)
            )

            VStack(alignment: .leading, spacing: 1) {
                Text(author.name)
                    .font(Type.bodyEmphasis)
                    .foregroundStyle(Label.primary)
                    .lineLimit(1)
                Text("\(author.count)")
                    .font(Type.meta(10))
                    .foregroundStyle(Label.tertiary)
            }
            .padding(.horizontal, Space.tight)
        }
        .padding(.bottom, Space.base)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(author.name), \(author.count) saved")
    }

    private func tile(_ item: Item) -> some View {
        MosaicTile(item: item, loader: loader)
    }
}

/// One quadrant of a cover. Deliberately not `ItemTile`: no press state, no tap target, no
/// fallback text -- it is texture, and a cover made of readable cards would compete with its
/// own label.
private struct MosaicTile: View {
    let item: Item
    let loader: ThumbnailLoader?

    @State private var image: UIImage?

    private var ground: Color {
        guard let packed = item.averageColor else { return Surface.elevated }
        let (r, g, b) = AverageColor.components(packed)
        return Color(.sRGB, red: r, green: g, blue: b)
    }

    var body: some View {
        ZStack {
            ground
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

/// One collection, opened.
private struct CollectionDetail: View {
    let author: String

    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ScrollView(showsIndicators: false) {
                    MasonryGrid(
                        items: state.items,
                        columns: Grid.columns,
                        spacing: Grid.gutter,
                        width: proxy.size.width - Grid.margin * 2
                    ) { item, _ in
                        ItemTile(item: item, loader: state.loader)
                            .onAppear {
                                if item.id == state.items.last?.id { state.loadMore() }
                            }
                    }
                    .padding(.horizontal, Grid.margin)
                    .padding(.top, Space.snug)
                }
            }
            .background(Surface.canvas)
            .navigationTitle(author)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Surface.canvas, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.font(Type.control)
                }
            }
        }
        .tint(Label.primary)
        .task { state.select(author: author) }
        // Filtering is app-wide state, so leaving the sheet has to put it back or the library
        // tab silently stays filtered to a collection nobody is looking at any more.
        .onDisappear { state.select(author: nil) }
    }
}
