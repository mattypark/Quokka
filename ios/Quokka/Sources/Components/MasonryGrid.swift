import SwiftUI
import QuokkaEngine
import QuokkaDesign

/// A masonry grid that lays tiles out at their **native** aspect ratio.
///
/// This is the one structural decision the whole look rests on. A reel is 9:16, a YouTube
/// thumbnail is 16:9, a pin is 2:3 -- forcing them into a uniform card grid would crop away
/// the composition of the thing being saved, which is the entire point of saving it. The
/// raggedness is the texture, and against a black ground the varied rectangles of colour
/// become the layout.
///
/// Columns are filled shortest-first rather than round-robin, so the bottom edge stays roughly
/// level even when a run of tall reels arrives together.
struct MasonryGrid<Content: View>: View {
    let items: [Item]
    let columns: Int
    let spacing: CGFloat
    let width: CGFloat
    @ViewBuilder let content: (Item, CGFloat) -> Content

    /// A tile still waiting on its thumbnail has no measured ratio. 3:4 is the neutral guess
    /// across a mixed feed, and a per-platform default would make tiles visibly jump when the
    /// real ratio lands.
    private static var pendingRatio: Double { 3.0 / 4.0 }

    /// A tile that will never have an image is a text card, not a photo, and giving it a
    /// portrait photo's shape leaves most of it empty. Slightly wide reads as a note.
    private static var textCardRatio: Double { 1.4 }

    private static func ratio(for item: Item) -> Double {
        if let measured = item.aspectRatio { return measured }
        switch item.thumbnailState {
        case .unavailable, .failed: return textCardRatio
        case .pending, .stored: return pendingRatio
        }
    }

    private var columnWidth: CGFloat {
        (width - spacing * CGFloat(columns - 1)) / CGFloat(columns)
    }

    /// Distributes items into columns, tracking running heights.
    private var buckets: [[(item: Item, height: CGFloat)]] {
        var result = Array(repeating: [(item: Item, height: CGFloat)](), count: columns)
        var heights = Array(repeating: CGFloat.zero, count: columns)

        for item in items {
            let ratio = Self.ratio(for: item)
            // Clamped: a panorama or an extremely tall image would otherwise produce one tile
            // that is most of a screen and wreck the rhythm of everything around it.
            let clamped = min(max(ratio, 0.5), 2.0)
            let height = columnWidth / clamped

            let shortest = heights.enumerated().min { $0.element < $1.element }?.offset ?? 0
            result[shortest].append((item, height))
            heights[shortest] += height + spacing
        }
        return result
    }

    var body: some View {
        HStack(alignment: .top, spacing: spacing) {
            ForEach(Array(buckets.enumerated()), id: \.offset) { _, column in
                LazyVStack(spacing: spacing) {
                    ForEach(column, id: \.item.id) { entry in
                        content(entry.item, entry.height)
                            .frame(width: columnWidth, height: entry.height)
                    }
                }
            }
        }
    }
}
