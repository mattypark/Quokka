import SwiftUI
import AllimDesign

/// Where the app's navigation lives.
///
/// A bottom bar rather than a top one, for the reason Pinterest and Cosmos both use it: the
/// grid is the whole app, and a top toolbar puts chrome between the person and the first row
/// of it. Down here it sits under the thumb and the content runs to the top edge of the screen.
///
/// Deliberately not `TabView`. The bar floats over the grid rather than pushing it up, so the
/// content scrolls underneath and stays edge-to-edge.
struct TabBar: View {
    enum Tab: String, CaseIterable {
        case library, collections, settings

        var icon: String {
            switch self {
            case .library: "square.grid.2x2"
            case .collections: "rectangle.stack"
            case .settings: "slider.horizontal.3"
            }
        }

        var title: String {
            switch self {
            case .library: "Everything"
            case .collections: "Collections"
            case .settings: "Settings"
            }
        }
    }

    @Binding var selection: Tab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    guard selection != tab else { return }
                    selection = tab
                    Haptics.shared.tick()
                } label: {
                    Image(systemName: tab.icon)
                        .font(.system(size: 19, weight: selection == tab ? .semibold : .regular))
                        .foregroundStyle(selection == tab ? Label.primary : Label.dim)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selection == tab ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(.horizontal, Space.snug)
        .background(
            // Translucent rather than solid: the grid scrolling underneath is what tells you
            // there is more, and a hard bar would cut that off.
            Capsule().fill(.regularMaterial)
                .overlay(Capsule().stroke(Surface.hairline, lineWidth: Stroke.thin))
        )
        .padding(.horizontal, Space.section)
        .shadow(color: .black.opacity(0.06), radius: 18, y: 6)
    }
}
