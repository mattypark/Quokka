import SwiftUI
import QuokkaDesign

/// Where the app's navigation lives: a black capsule floating on the page.
///
/// Black because the mark is black -- the bar is the one piece of the brand you see on every
/// screen -- and floating so the grid runs underneath it to the bottom edge. The open tab is
/// white with a sky dot under it; the others sit back at half strength.
struct TabBar: View {
    enum Tab: String, CaseIterable {
        case home, library, studio

        var title: String {
            switch self {
            case .home: "Home"
            case .library: "Library"
            case .studio: "Studio"
            }
        }

        var icon: String {
            switch self {
            case .home: "house.fill"
            case .library: "square.grid.2x2.fill"
            case .studio: "pencil.and.scribble"
            }
        }
    }

    let selection: Tab
    /// Asked rather than assigned, so the root can run the sky's transition on the way.
    var onSelect: (Tab) -> Void = { _ in }
    /// Tapping the open tab again scrolls it back to the top.
    var onReselect: (Tab) -> Void = { _ in }

    var body: some View {
        HStack(spacing: Space.tight) {
            ForEach(Tab.allCases, id: \.self) { tab in
                let active = selection == tab
                Button {
                    Haptics.shared.tick()
                    if active { onReselect(tab) } else { onSelect(tab) }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(active ? Label.onInverse : Label.onInverse.opacity(0.5))
                        Circle()
                            .fill(active ? Sky.bottom : .clear)
                            .frame(width: 4, height: 4)
                    }
                    .frame(width: 64, height: 54)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(.horizontal, Space.snug)
        .background(
            Capsule()
                .fill(Surface.inverse)
                .shadow(color: .black.opacity(0.22), radius: 18, y: 8)
        )
    }
}
