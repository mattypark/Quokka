import SwiftUI
import AllimDesign
import AllimEngine

/// Images strewn across the screen at irregular sizes, with the wordmark set through them.
///
/// The scatter is **seeded, not random**. A layout that differs on every launch is a different
/// accident each time; one that is art-directed once and then reproduces exactly is a designed
/// screen. The seed is a constant so it can be tuned and then stays tuned.
struct ScatteredGallery: View {
    let items: [Item]
    let loader: ThumbnailLoader?

    /// Normalised placements: x and y in 0...1, width as a fraction of the container, and a
    /// small rotation. Hand-placed so the wordmark's band across the middle stays clear.
    private static let placements: [(x: CGFloat, y: CGFloat, width: CGFloat, angle: Double)] = [
        (0.20, 0.16, 0.15, -4),
        (0.48, 0.08, 0.19, 2),
        (0.76, 0.19, 0.16, 5),
        (0.88, 0.38, 0.11, -3),
        (0.13, 0.40, 0.12, 3),
        (0.17, 0.74, 0.16, 3),
        (0.44, 0.86, 0.13, -6),
        (0.71, 0.76, 0.20, 2),
    ]

    /// Only items with a picture. A blank tile in a scatter does not read as a placeholder,
    /// it reads as a hole in the layout.
    private var usable: [Item] {
        items.filter { $0.thumbnailState == .stored }
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(Array(Self.placements.enumerated()), id: \.offset) { index, place in
                    // Wraps rather than stopping: a short library still fills the screen, and
                    // the same picture appearing twice at different sizes reads as a collage.
                    if !usable.isEmpty {
                        let item = usable[index % usable.count]
                        let width = proxy.size.width * place.width
                        ScatterTile(item: item, loader: loader)
                            .frame(width: width, height: width * 1.25)
                            .rotationEffect(.degrees(place.angle))
                            .position(x: proxy.size.width * place.x, y: proxy.size.height * place.y)
                    }
                }
            }
        }
    }
}

private struct ScatterTile: View {
    let item: Item
    let loader: ThumbnailLoader?

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Surface.elevated
            if let image {
                Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
            }
        }
        .clipped()
        .tileShape(.control, stroked: false)
        .shadow(color: .black.opacity(0.10), radius: 10, y: 3)
        .task(id: item.id) {
            guard let loader, let id = item.id, item.thumbnailState == .stored else { return }
            image = await loader.image(for: id)
        }
    }
}
