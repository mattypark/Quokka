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
    var onPreview: (() -> Void)?
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
            Color.white.ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer()
                AnimatedQuokka(.thinking, size: 104)
                Text(carriesVideo ? "extracting idea…" : "saving…")
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .foregroundStyle(.black.opacity(0.45))
                Spacer()
            }

            VStack {
                HStack {
                    Spacer()
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.black.opacity(0.35))
                        .padding(22)
                }
                Spacer()
            }
        }
    }

    // MARK: - Saved / rejected

    private var card: some View {
        VStack {
            Spacer()
            VStack(spacing: 16) {
                HStack {
                    Text(state == .saved ? "Video saved!" : "Nothing to save")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.black)
                    Spacer()
                    Button { onDone?() } label: {
                        Text("Done")
                            .font(.system(size: 15))
                            .foregroundStyle(.black.opacity(0.45))
                    }
                }

                if state == .saved {
                    AnimatedQuokka(.celebrating, size: 62)

                    Button { onPreview?() } label: {
                        Text("Preview")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .overlay(Capsule().stroke(.black.opacity(0.18), lineWidth: 1))
                    }

                    Button { onOpen?() } label: {
                        HStack(spacing: 6) {
                            Text("Open in app").font(.system(size: 15, weight: .semibold))
                            Image(systemName: "arrow.up.forward.square").font(.system(size: 13))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(.black))
                    }
                } else {
                    Text("No link or video came through in that share.")
                        .font(.system(size: 13))
                        .foregroundStyle(.black.opacity(0.45))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(20)
            .background(
                UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22)
                    .fill(.white)
            )
        }
        // A Color needs ignoresSafeArea applied to the view, not folded into the style --
        // the ShapeStyle overload does not take it.
        .background(Color.black.opacity(0.22).ignoresSafeArea())
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
                    .fill(.black)
                    .frame(width: 11, height: 11)
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
