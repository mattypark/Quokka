import SwiftUI
import QuokkaDesign

// The handful of controls every screen is built from. Each one is measured off Cosmos -- see
// docs/DESIGN-REFS.md -- and lives here so a screen never re-derives a size or a fill.

/// A grey-filled circle: back, search, more.
struct CircleButton: View {
    let icon: String
    let label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            CircleGlyph(icon: icon)
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(label)
    }
}

/// The circle without the button, for use inside a `Menu`, `ShareLink` or `NavigationLink`
/// label -- each of which is already the button.
struct CircleGlyph: View {
    let icon: String

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(Label.primary)
            .frame(width: Control.circle, height: Control.circle)
            .background(Surface.control, in: Circle())
            .contentShape(Circle())
    }
}

/// A circle with a hairline and no fill -- the icon buttons beside a filled pill.
struct OutlineCircle: View {
    let icon: String

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 16, weight: .regular))
            .foregroundStyle(Label.primary)
            .frame(width: Control.circle, height: Control.circle)
            .overlay(Circle().stroke(Surface.hairline, lineWidth: Stroke.regular))
            .contentShape(Circle())
    }
}

/// The black pill -- Follow, Save, Get started.
struct FilledPill: View {
    let title: String
    var icon: String?

    var body: some View {
        HStack(spacing: Space.snug) {
            if let icon {
                Image(systemName: icon).font(.system(size: 14, weight: .semibold))
            }
            Text(title).font(Type.control).tracking(Type.navTracking)
        }
        .foregroundStyle(Label.onInverse)
        .frame(maxWidth: .infinity)
        .frame(height: Control.pillHeight)
        .background(Surface.inverse, in: Capsule())
        .contentShape(Capsule())
    }
}

/// The white pill with a hairline -- Cosmos's "Create".
struct OutlinePill: View {
    let title: String
    var icon: String?

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon).font(.system(size: 13, weight: .semibold))
            }
            Text(title).font(Type.control).tracking(Type.navTracking)
        }
        .foregroundStyle(Label.primary)
        .padding(.horizontal, Space.roomy)
        .frame(height: 36)
        .background(Surface.canvas, in: Capsule())
        .overlay(Capsule().stroke(Surface.hairline, lineWidth: Stroke.thin))
        .contentShape(Capsule())
    }
}

/// Press feedback for anything that is not a system button: a small scale, no highlight.
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? Motion.pressedScale : 1)
            .animation(Motion.respecting(Motion.press), value: configuration.isPressed)
    }
}

/// Text tabs centered in a top bar -- "For You  Following" in Cosmos.
///
/// Weight never changes between states, only colour, so the words do not shift sideways as
/// the selection moves.
struct TextTabs<Value: Hashable>: View {
    let options: [(value: Value, title: String)]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: Space.loose) {
            ForEach(options, id: \.value) { option in
                let active = selection == option.value
                Button {
                    guard !active else { return }
                    selection = option.value
                    Haptics.shared.tick()
                } label: {
                    Text(option.title)
                        .font(Type.nav)
                        .tracking(Type.navTracking)
                        .foregroundStyle(active ? Label.primary : Label.secondary)
                        .padding(.vertical, Space.snug)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
            }
        }
    }
}

/// Tabs that split the width, with a black underline under the active one and a hairline
/// under the row -- the profile's "Elements  Clusters".
struct UnderlineTabs<Value: Hashable>: View {
    let options: [(value: Value, title: String, count: Int?)]
    @Binding var selection: Value

    @Namespace private var underline

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.value) { option in
                let active = selection == option.value
                Button {
                    guard !active else { return }
                    withAnimation(Motion.respecting(.spring(response: 0.3, dampingFraction: 0.88))) {
                        selection = option.value
                    }
                    Haptics.shared.tick()
                } label: {
                    VStack(spacing: 0) {
                        HStack(spacing: 6) {
                            Text(option.title)
                                .font(Type.nav)
                                .tracking(Type.navTracking)
                                .foregroundStyle(active ? Label.primary : Label.secondary)
                            if let count = option.count, active {
                                CountBadge(count: count)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)

                        ZStack {
                            if active {
                                Rectangle()
                                    .fill(Label.primary)
                                    .matchedGeometryEffect(id: "underline", in: underline)
                            }
                        }
                        .frame(height: Stroke.underline)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
            }
        }
        .background(alignment: .bottom) {
            Rectangle().fill(Surface.hairline).frame(height: Stroke.thin)
        }
    }
}

/// The outlined count beside a tab title. Abbreviated past a thousand, because the badge is a
/// sense of size and "2,143" is a number to read.
struct CountBadge: View {
    let count: Int

    var body: some View {
        Text(Self.abbreviated(count))
            .font(Type.badge)
            .foregroundStyle(Label.primary)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .overlay(Capsule().stroke(Surface.hairlineStrong, lineWidth: Stroke.regular))
    }

    static func abbreviated(_ count: Int) -> String {
        switch count {
        case ..<1_000: "\(count)"
        case ..<10_000:
            String(format: "%.1fK", Double(count) / 1_000).replacingOccurrences(of: ".0K", with: "K")
        case ..<1_000_000: "\(count / 1_000)K"
        default:
            String(format: "%.1fM", Double(count) / 1_000_000).replacingOccurrences(of: ".0M", with: "M")
        }
    }
}

/// Three slots: something on the left, something centered, something on the right. The center
/// stays centered on the screen however wide the sides are, which an HStack with Spacers
/// cannot promise.
struct TopBar<Leading: View, Center: View, Trailing: View>: View {
    @ViewBuilder var leading: Leading
    @ViewBuilder var center: Center
    @ViewBuilder var trailing: Trailing

    var body: some View {
        ZStack {
            center
            HStack {
                leading
                Spacer(minLength: 0)
                trailing
            }
        }
        .padding(.horizontal, Space.roomy)
        .frame(height: 52)
        .background(Surface.canvas)
    }
}

/// A quiet centered message for an empty list or pane.
struct EmptyNote: View {
    let title: String
    var detail: String?

    var body: some View {
        VStack(spacing: Space.snug) {
            Text(title)
                .font(Type.bodyEmphasis)
                .foregroundStyle(Label.primary)
            if let detail {
                Text(detail)
                    .font(Type.caption)
                    .foregroundStyle(Label.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, Space.section)
        .padding(.vertical, Space.chapter)
        .frame(maxWidth: .infinity)
    }
}
