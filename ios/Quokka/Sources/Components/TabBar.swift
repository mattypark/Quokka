import SwiftUI
import QuokkaDesign

/// Where the app's navigation lives.
///
/// A small white pill resting on the grid, not a bar across it -- Cosmos's is about 155pt
/// wide with three glyphs, and at that size it reads as an object rather than as chrome. The
/// grid runs to every edge of the screen and scrolls underneath.
///
/// Deliberately not `TabView`, which would push the content up and draw a full-width bar.
struct TabBar: View {
    enum Tab: String, CaseIterable {
        case home, search, profile

        var title: String {
            switch self {
            case .home: "Home"
            case .search: "Search"
            case .profile: "Profile"
            }
        }
    }

    @Binding var selection: Tab
    /// Tapping the tab you are already on scrolls it back to the top, as every feed app does.
    var onReselect: (Tab) -> Void = { _ in }

    @Environment(ProfileIdentity.self) private var profile

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    Haptics.shared.tick()
                    if selection == tab {
                        onReselect(tab)
                    } else {
                        selection = tab
                    }
                } label: {
                    glyph(tab)
                        .frame(width: 52, height: 48)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selection == tab ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(.horizontal, Space.tight)
        .background(
            Capsule()
                .fill(Surface.canvas)
                .overlay(Capsule().stroke(Surface.hairline, lineWidth: Stroke.thin))
                .shadow(color: .black.opacity(0.08), radius: 16, y: 4)
        )
    }

    @ViewBuilder
    private func glyph(_ tab: Tab) -> some View {
        let active = selection == tab
        switch tab {
        case .home:
            Image(systemName: active ? "house.fill" : "house")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(active ? Label.primary : Label.dim)
        case .search:
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: active ? .semibold : .medium))
                .foregroundStyle(active ? Label.primary : Label.dim)
        case .profile:
            Avatar(image: profile.avatar, name: profile.name, size: 24)
                .padding(2)
                .overlay(Circle().stroke(active ? Label.primary : .clear, lineWidth: 1.5))
        }
    }
}
