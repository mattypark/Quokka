import SwiftUI
import QuokkaDesign

// The handful of controls every screen is built from. Each lives here so a screen never
// re-derives a size or a fill -- and so a custom face or a new blue is one edit, not forty.

/// A white circle on the paper, or a glass one on the sky: back, share, more.
struct CircleButton: View {
    let icon: String
    let label: String
    var onSky = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            CircleGlyph(icon: icon, onSky: onSky)
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(label)
    }
}

/// The circle without the button, for use inside a `Menu`, `ShareLink` or `NavigationLink`.
struct CircleGlyph: View {
    let icon: String
    var onSky = false

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(onSky ? Label.onSky : Label.primary)
            .frame(width: Control.circle, height: Control.circle)
            .background {
                if onSky {
                    Circle().fill(Sky.glass).overlay(Circle().stroke(Sky.glassStroke, lineWidth: Stroke.thin))
                } else {
                    Circle().fill(Surface.control)
                        .overlay(Circle().stroke(Surface.hairline, lineWidth: Stroke.thin))
                        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
                }
            }
            .contentShape(Circle())
    }
}

/// A circle with a hairline and no fill.
struct OutlineCircle: View {
    let icon: String

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(Label.primary)
            .frame(width: Control.circle, height: Control.circle)
            .background(Surface.raised, in: Circle())
            .overlay(Circle().stroke(Surface.hairlineStrong, lineWidth: Stroke.regular))
            .contentShape(Circle())
    }
}

/// The full-width pill. Blue does something to a video; black is everything else; white sits
/// on the sky.
struct FilledPill: View {
    enum Tone { case sky, ink, white }

    let title: String
    var icon: String?
    var tone: Tone = .sky

    private var fill: Color {
        switch tone {
        case .sky: Sky.accent
        case .ink: Surface.inverse
        case .white: Ink.white
        }
    }

    private var ink: Color { tone == .white ? Sky.accent : Label.onInverse }

    var body: some View {
        HStack(spacing: Space.snug) {
            if let icon {
                Image(systemName: icon).font(.system(size: 15, weight: .semibold))
            }
            Text(title).font(Type.control)
        }
        .foregroundStyle(ink)
        .frame(maxWidth: .infinity)
        .frame(height: Control.pillHeight)
        .background(fill, in: Capsule())
        .contentShape(Capsule())
    }
}

/// A small white pill with a hairline -- "Open", "Copy ask".
struct OutlinePill: View {
    let title: String
    var icon: String?

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon).font(.system(size: 13, weight: .semibold))
            }
            Text(title).font(.system(size: 15, weight: .semibold))
        }
        .foregroundStyle(Label.primary)
        .padding(.horizontal, Space.roomy)
        .frame(height: 38)
        .background(Surface.raised, in: Capsule())
        .overlay(Capsule().stroke(Surface.hairlineStrong, lineWidth: Stroke.thin))
        .contentShape(Capsule())
    }
}

/// A glass pill on the sky, the way Nudgy lays its header actions.
struct GlassPill: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: Space.snug) {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold))
            Text(title).font(Type.control)
        }
        .foregroundStyle(Label.onSky)
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background(Sky.glass, in: Capsule())
        .overlay(Capsule().stroke(Sky.glassStroke, lineWidth: Stroke.thin))
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

/// A white card on the paper.
struct Card<Content: View>: View {
    var padding: CGFloat = Space.roomy
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Surface.raised, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }
}

/// The uppercase tracked label over a group of cards.
struct SectionLabel: View {
    let text: String
    var trailing: String?
    /// Translucent white over the sky instead of grey, which would sink into the blue.
    var onSky = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(text.uppercased())
                .font(Type.section)
                .tracking(Type.sectionTracking)
                .foregroundStyle(onSky ? Label.onSkySecondary : Label.secondary)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(Type.meta(12))
                    .foregroundStyle(onSky ? Label.onSkySecondary : Label.tertiary)
            }
        }
        .accessibilityAddTraits(.isHeader)
    }
}

/// A filter chip. Selected is black; the rest are white with a hairline.
struct Chip: View {
    let title: String
    let selected: Bool
    var action: () -> Void

    var body: some View {
        Button {
            Haptics.shared.tick()
            action()
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(selected ? Label.onInverse : Label.primary)
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(selected ? Surface.inverse : Surface.raised, in: Capsule())
                .overlay(Capsule().stroke(selected ? .clear : Surface.hairlineStrong, lineWidth: Stroke.thin))
        }
        .buttonStyle(PressStyle())
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Text tabs -- weight never changes between states, only colour, so words do not shift.
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
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(active ? Label.primary : Label.dim)
                        .padding(.vertical, Space.snug)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
            }
        }
    }
}

/// Tabs that split the width, with a black underline under the active one -- Nudgy's
/// Overview / Transcript / Voice row.
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
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(active ? Label.primary : Label.dim)
                            if let count = option.count, active {
                                CountBadge(count: count)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)

                        ZStack {
                            if active {
                                Capsule()
                                    .fill(Label.primary)
                                    .matchedGeometryEffect(id: "underline", in: underline)
                            }
                        }
                        .frame(height: Stroke.underline)
                        .padding(.horizontal, Space.loose)
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

/// The outlined count beside a tab title. Abbreviated past a thousand.
struct CountBadge: View {
    let count: Int

    var body: some View {
        Text(Self.abbreviated(count))
            .font(Type.badge)
            .foregroundStyle(Label.primary)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(Surface.field, in: Capsule())
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

/// Three slots: left, centered, right. The center stays centered on the screen however wide
/// the sides are.
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
        .padding(.horizontal, Space.gutter)
        .frame(height: 52)
    }
}

/// A big hand-drawn screen title with an optional control on the right.
struct ScreenTitle<Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Type.hand(38))
                    .foregroundStyle(Label.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(Type.caption)
                        .foregroundStyle(Label.secondary)
                }
            }
            Spacer(minLength: Space.base)
            trailing
        }
        .padding(.horizontal, Space.gutter)
        .padding(.top, Space.base)
        .accessibilityElement(children: .contain)
    }
}

extension ScreenTitle where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

/// A quiet empty state: the mark, a line in its hand, and what fills it in.
struct EmptyNote: View {
    let title: String
    var detail: String?

    var body: some View {
        VStack(spacing: Space.base) {
            QuokkaMark(size: 44, blinks: true)
            Text(title)
                .font(Type.hand(24))
                .foregroundStyle(Label.primary)
                .multilineTextAlignment(.center)
            if let detail {
                Text(detail)
                    .font(Type.caption)
                    .foregroundStyle(Label.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, Space.section)
        .padding(.vertical, Space.section)
        .frame(maxWidth: .infinity)
    }
}
