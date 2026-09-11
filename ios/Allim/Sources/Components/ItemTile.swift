import SwiftUI
import AllimEngine
import AllimImaging
import AllimDesign

/// One tile in the grid, in the three states a tile can be in.
struct ItemTile: View {
    let item: Item
    let loader: ThumbnailLoader?

    @State private var image: UIImage?
    @State private var pressed = false

    /// The four bytes stored inline on the row. No decode, no hash -- see `AverageColor`.
    private var ground: Color {
        guard let packed = item.averageColor else { return Surface.elevated }
        let (r, g, b) = AverageColor.components(packed)
        return Color(.sRGB, red: r, green: g, blue: b)
    }

    var body: some View {
        ZStack {
            ground
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .transition(.opacity)
            } else if item.thumbnailState != .pending {
                // Anything that is not still waiting gets the typographic tile. Gating this on
                // .unavailable alone left failed fetches as blank grey rectangles, which reads
                // as a broken app rather than as a post without a picture.
                FallbackTile(item: item, retryable: item.thumbnailState == .failed)
            }
        }
        .tileShape(.tile)
        .scaleEffect(pressed ? Motion.pressedScale : 1)
        .animation(Motion.respecting(Motion.press), value: pressed)
        .contentShape(Rectangle())
        .onTapGesture { open() }
        .onLongPressGesture(minimumDuration: 0.01, pressing: { pressed = $0 }, perform: {})
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
        .task(id: item.id) {
            guard let loader, let id = item.id, item.thumbnailState == .stored else { return }
            let loaded = await loader.image(for: id)
            withAnimation(Motion.respecting(.easeOut(duration: 0.2))) { image = loaded }
        }
    }

    private var accessibilityLabel: String {
        [item.platform.displayName, item.author, item.title]
            .compactMap { $0 }
            .joined(separator: ", ")
    }

    /// There is only ever one derivative, so the tile is not a viewer -- tapping goes to the
    /// post. That is also what keeps the library at 15.9 GB instead of 76.8.
    private func open() {
        guard let url = URL(string: item.url) else { return }
        Haptics.shared.tick()
        UIApplication.shared.open(url)
    }
}

/// The designed state for Instagram, Pinterest and X, which serve no image to an
/// unauthenticated client. A title set in the editorial face IS the artwork here; committing
/// to black and white is what makes this read as intent rather than as a broken image.
private struct FallbackTile: View {
    let item: Item
    var retryable = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.snug) {
            Text(item.platform.displayName.lowercased())
                .font(Type.meta(9))
                .foregroundStyle(Label.tertiary)
            if let author = item.author {
                Text(author)
                    .font(Type.tileTitle(16))
                    .foregroundStyle(Label.primary)
                    .lineLimit(3)
            } else if let title = item.title {
                Text(title)
                    .font(Type.tileTitle(15))
                    .foregroundStyle(Label.primary)
                    .lineLimit(4)
            }
            if let caption = item.caption, !caption.isEmpty {
                // What Matthew typed when he sent it to himself. On a platform that publishes
                // no metadata at all, his own note is the best description that will ever exist.
                Text(caption)
                    .font(Type.caption)
                    .foregroundStyle(Label.tertiary)
                    .lineLimit(3)
            }
            Spacer(minLength: 0)
            HStack(spacing: Space.tight) {
                Text(item.contentID ?? "")
                    .font(Type.meta(8))
                    .foregroundStyle(Label.tertiary)
                    .lineLimit(1)
                if retryable {
                    Spacer(minLength: 0)
                    // Distinguishes "this platform never had a picture" from "the fetch did
                    // not work this time", which are different things to a person looking at
                    // an identical-looking tile.
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 8))
                        .foregroundStyle(Label.tertiary)
                }
            }
        }
        .padding(Space.base)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Surface.raised)
    }
}
