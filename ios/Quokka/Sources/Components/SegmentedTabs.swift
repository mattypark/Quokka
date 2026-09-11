import SwiftUI
import QuokkaDesign

/// Two-up segmented control -- Note|Inspiration, Ideas|Media.
///
/// Hand-rolled rather than `Picker(.segmented)`, because the reference has a white raised pill
/// on a light track with a soft shadow, and the system control cannot be pushed there without
/// appearance hacks that break on the next OS.
struct SegmentedTabs<Value: Hashable>: View {
    let options: [(value: Value, title: String)]
    @Binding var selection: Value

    @Namespace private var pill

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.value) { option in
                let active = selection == option.value
                Button {
                    guard !active else { return }
                    withAnimation(Motion.respecting(.spring(response: 0.3, dampingFraction: 0.86))) {
                        selection = option.value
                    }
                    Haptics.shared.tick()
                } label: {
                    Text(option.title)
                        .font(active ? Type.bodyEmphasis : Type.body)
                        .foregroundStyle(active ? Label.primary : Label.tertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background {
                            if active {
                                // matchedGeometryEffect so the pill slides between segments
                                // rather than cross-fading, which is what makes it feel like
                                // one object moving instead of two appearing.
                                Capsule()
                                    .fill(Surface.canvas)
                                    .shadow(color: .black.opacity(0.07), radius: 5, y: 1)
                                    .matchedGeometryEffect(id: "pill", in: pill)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(3)
        .background(Capsule().fill(Surface.elevated))
    }
}
