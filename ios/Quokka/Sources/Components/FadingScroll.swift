import SwiftUI
import QuokkaDesign

/// A scroll view whose bottom edge dissolves, and stops dissolving once there is nothing left
/// to reach.
///
/// A hard bottom edge on a long transcript says "the text ends here". A soft one says "there
/// is more", which is true, and it is the difference between a screen that looks finished and
/// one that looks cut off. The fade then retracts as the last line arrives, because a fade
/// that never lifts hides the end of the thing you scrolled all that way to read.
///
/// Masked rather than overlaid with a gradient in the background colour. An overlay only works
/// on an opaque, known ground; a mask works on anything and cannot drift out of sync with the
/// palette.
struct FadingScroll<Content: View>: View {
    var fade: CGFloat = 96
    @ViewBuilder var content: Content

    /// How much room is left below. Drives the fade directly rather than through a
    /// derived Bool, so the edge softens and hardens smoothly instead of snapping.
    @State private var remaining: CGFloat = .greatestFiniteMagnitude

    var body: some View {
        ScrollView(showsIndicators: false) {
            content
        }
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            // Distance from the current bottom edge to the very bottom of the content.
            geometry.contentSize.height
                - geometry.contentOffset.y
                - geometry.containerSize.height
                + geometry.contentInsets.bottom
        } action: { _, distance in
            remaining = max(0, distance)
        }
        .mask(alignment: .top) {
            GeometryReader { proxy in
                let height = proxy.size.height
                // Full strength while there is more than a fade's worth still to come, then
                // proportionally weaker as the end approaches.
                let strength = min(1, remaining / fade)
                let start = height <= 0 ? 1 : 1 - (fade * strength) / height

                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black, location: max(0, start)),
                        .init(color: .black.opacity(0), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }
}
