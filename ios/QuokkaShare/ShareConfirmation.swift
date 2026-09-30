import SwiftUI
import QuokkaEngine
import QuokkaDesign

/// What the share sheet shows while it works, and when it is done.
///
/// Two presentations, because the two moments are not the same shape. Extracting takes over
/// the screen -- there is nothing to decide and something to watch. Saved is a card at the
/// bottom, because now there are choices and the video underneath should stay visible.
struct ShareConfirmation: View {
    enum State: Equatable { case working, saved, rejected }

    let state: State
    let platform: Platform?
    var carriesVideo = false
    var onOpen: (() -> Void)?
    var onDone: (() -> Void)?

    var body: some View {
        switch state {
        case .working: working
        case .saved, .rejected: card
        }
    }

    // MARK: - Working

    private var working: some View {
        ZStack {
            Surface.canvas.ignoresSafeArea()

            VStack(spacing: Space.roomy) {
                QuokkaMark(size: 56, blinks: true)
                PulsingDots()
                Text(carriesVideo ? "Reading the video" : "Saving")
                    .font(Type.hand(22))
                    .foregroundStyle(Label.secondary)
            }
        }
    }

    // MARK: - Saved / rejected

    /// A white card at the bottom, the way Cosmos confirms a save: what happened, where it
    /// came from, one black pill and a quiet way out. The post underneath stays visible.
    private var card: some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: Space.roomy) {
                HStack(spacing: Space.base) {
                    if state == .saved {
                        QuokkaMark(size: 40, blinks: true)
                    } else {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Label.secondary)
                            .frame(width: 40, height: 40)
                            .background(Surface.field, in: Circle())
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(state == .saved ? "Saved to Quokka" : "Nothing to save")
                            .font(Type.hand(22))
                            .foregroundStyle(Label.primary)
                        Text(subtitle)
                            .font(Type.caption)
                            .foregroundStyle(Label.secondary)
                    }
                    Spacer(minLength: 0)
                    Button { onDone?() } label: {
                        Text("Done")
                            .font(Type.control)
                            .foregroundStyle(Label.secondary)
                            .padding(.vertical, Space.snug)
                    }
                }

                if state == .saved {
                    Button { onOpen?() } label: {
                        HStack(spacing: 6) {
                            Text("Open Quokka").font(Type.control)
                            Image(systemName: "arrow.up.right").font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(Label.onInverse)
                        .frame(maxWidth: .infinity)
                        .frame(height: Control.pillHeight)
                        .background(Sky.accent, in: Capsule())
                    }
                }
            }
            .padding(Space.loose)
            .padding(.bottom, Space.snug)
            .background(
                UnevenRoundedRectangle(topLeadingRadius: Radius.sheet, topTrailingRadius: Radius.sheet)
                    .fill(Surface.raised)
                    .ignoresSafeArea(edges: .bottom)
            )
        }
        // A Color needs ignoresSafeArea applied to the view, not folded into the style --
        // the ShapeStyle overload does not take it.
        .background(Color.black.opacity(0.22).ignoresSafeArea())
    }

    private var subtitle: String {
        guard state == .saved else { return "No link or video came through in that share." }
        let kind = carriesVideo ? "Video" : "Link"
        if let platform { return "\(kind) from \(platform.displayName)" }
        return kind
    }
}

/// Three dots, breathing.
///
/// A spinner says "the system is busy"; this reads as something being worked out, which is
/// closer to what is happening and is the one moment the extension has any personality.
private struct PulsingDots: View {
    @State private var phase = 0.0

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Sky.accent)
                    .frame(width: 9, height: 9)
                    .scaleEffect(0.7 + 0.3 * pulse(index))
                    .opacity(0.35 + 0.65 * pulse(index))
            }
        }
        .task {
            // Driven by a timer rather than a repeating animation, so the three dots stay in a
            // fixed phase relationship instead of drifting apart over a long extraction.
            guard !UIAccessibility.isReduceMotionEnabled else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(60))
                phase += 0.06
            }
        }
    }

    private func pulse(_ index: Int) -> Double {
        let offset = Double(index) * 0.55
        return (sin((phase - offset) * 2.4) + 1) / 2
    }
}
