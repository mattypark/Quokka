import SwiftUI
import QuokkaDesign

/// The title that sits over the grid.
///
/// It scrolls away rather than staying pinned, because on a screen whose entire job is a wall
/// of pictures a permanent header is a permanent tax. It comes back when you reach the top.
struct FloatingHeader: View {
    let title: String
    let subtitle: String?
    var trailing: (() -> AnyView)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Type.title(28))
                    .foregroundStyle(Label.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(Type.meta(11))
                        .foregroundStyle(Label.tertiary)
                }
            }
            Spacer(minLength: Space.base)
            trailing?()
        }
        .padding(.horizontal, Space.roomy)
        .padding(.top, Space.base)
        .padding(.bottom, Space.roomy)
    }
}
