import SwiftUI
import QuokkaEngine
import QuokkaImaging
import QuokkaDesign

/// One tile in the grid, in the three states a tile can be in.
///
/// No chrome: no card, no outline, no caption under it. The saved image at its own shape is
/// the whole tile, which is what makes a Cosmos grid read as a wall of work rather than a list
/// of posts.
struct ItemTile: View {
    let item: Item
    let loader: ThumbnailLoader?

    @State private var image: UIImage?

    /// The four bytes stored inline on the row. No decode, no hash -- see `AverageColor`.
    private var ground: Color {
        guard let packed = item.averageColor else { return Surface.raised }
        let (r, g, b) = AverageColor.components(packed)
        return Color(.sRGB, red: r, green: g, blue: b)
    }

    var body: some View {
        // The ground takes the proposed size and the picture fills it as an overlay, so a tile is
        // always exactly the size it was given -- a filled image as a sibling would size the
        // tile to itself and spill out of any container that does not pin both dimensions.
        ground
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .transition(.opacity)
                } else if item.thumbnailState == .unavailable || item.thumbnailState == .failed {
                    // Only the two terminal states. A stored thumbnail still decoding shows its
                    // average colour, not a text card that flashes away a moment later.
                    FallbackTile(item: item, retryable: item.thumbnailState == .failed)
                }
            }
            .clipped()
        .tileShape(.tile)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
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
}

/// A tile that opens its item.
///
/// The tile itself stays inert so it can be reused as a cover or a thumbnail inside some
/// other control; only this wrapper makes it a way in.
struct TileLink: View {
    let item: Item
    let loader: ThumbnailLoader?

    var body: some View {
        if let id = item.id {
            NavigationLink(value: Route.item(id)) {
                ItemTile(item: item, loader: loader)
            }
            .buttonStyle(PressStyle())
            .accessibilityAddTraits(.isButton)
        } else {
            ItemTile(item: item, loader: loader)
        }
    }
}

/// The designed state for Instagram, Pinterest and X, which serve no image to an
/// unauthenticated client.
///
/// Quiet on purpose: the platform in small grey type, the author at size, the note if there
/// is one. Among photographs it should read as a card someone wrote on, not as an error.
private struct FallbackTile: View {
    let item: Item
    var retryable = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.tight) {
            HStack(spacing: Space.tight) {
                Text(item.platform.displayName)
                    .font(Type.caption)
                    .foregroundStyle(Label.secondary)
                if retryable {
                    Spacer(minLength: 0)
                    // Distinguishes "this platform never had a picture" from "the fetch did
                    // not work this time", which look identical otherwise.
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Label.dim)
                }
            }
            Spacer(minLength: 0)
            if let author = item.author {
                Text(author)
                    .font(Type.tileTitle(16))
                    .foregroundStyle(Label.primary)
                    .lineLimit(2)
            } else if let title = item.title {
                Text(title)
                    .font(Type.tileTitle(15))
                    .foregroundStyle(Label.primary)
                    .lineLimit(3)
            }
            if let caption = item.caption, !caption.isEmpty {
                // What Matthew typed when he sent it to himself. On a platform that publishes
                // no metadata at all, his own note is the best description that will exist.
                Text(caption)
                    .font(Type.caption)
                    .foregroundStyle(Label.secondary)
                    .lineLimit(2)
            }
        }
        .padding(Space.base)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Surface.field)
    }
}
