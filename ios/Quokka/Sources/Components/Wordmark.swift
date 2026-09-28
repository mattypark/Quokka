import SwiftUI
import QuokkaDesign

/// The name, set in the interface face.
///
/// Lowercase SF Pro at medium weight, tracked in. A display face here would be the one loud
/// thing on a screen whose only colour is supposed to be the saved work -- Cosmos's mark is
/// a small black glyph in the corner for the same reason.
struct Wordmark: View {
    var size: CGFloat = 19

    var body: some View {
        Text("quokka")
            .font(.system(size: size, weight: .semibold))
            .tracking(-size * 0.03)
            .foregroundStyle(Label.primary)
            .accessibilityLabel("Quokka")
    }
}
