import SwiftUI
import QuokkaDesign

/// The first screen.
///
/// Type and nothing else. On a first launch the library is empty, so a gallery here would be a
/// gallery of grey squares -- and a Cosmos-style opener works because it is quiet: one large
/// line, three short promises, one black pill.
struct OnboardingView: View {
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Wordmark()
                .padding(.top, Space.base)

            Spacer(minLength: Space.loose)

            VStack(spacing: Space.roomy) {
                Text("Save what stops\nyour thumb.")
                    .font(Type.headline)
                    .tracking(Type.headlineTracking)
                    .foregroundStyle(Label.primary)
                    .multilineTextAlignment(.center)
                Text("Everything you save, in one place — and something to make from it.")
                    .font(Type.body)
                    .foregroundStyle(Label.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Space.section)

            Spacer(minLength: Space.loose)

            VStack(alignment: .leading, spacing: Space.loose) {
                Promise(
                    icon: "square.and.arrow.up",
                    title: "Save from any app",
                    detail: "Share a post from Instagram, TikTok, YouTube or anywhere else.")
                Promise(
                    icon: "magnifyingglass",
                    title: "Find it again",
                    detail: "Search by word, by creator, or by colour.")
                Promise(
                    icon: "text.quote",
                    title: "Make something from it",
                    detail: "Playlists, and scripts built from what you saved.")
            }
            .padding(.horizontal, Space.section)

            Spacer(minLength: Space.loose)

            VStack(spacing: Space.base) {
                Button {
                    Haptics.shared.saved()
                    onStart()
                } label: {
                    FilledPill(title: "Get started")
                }
                .buttonStyle(PressStyle())

                // Markdown links rather than plain text, so both documents are one tap away
                // from the sentence that cites them.
                Text("By continuing you agree to the [Terms](\(Legal.terms)) and [Privacy Policy](\(Legal.privacy)).")
                    .font(Type.caption)
                    .foregroundStyle(Label.secondary)
                    .tint(Label.primary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Space.loose)
            .padding(.bottom, Space.base)
        }
        .background(Surface.canvas)
    }
}

/// One line of what the app does: a glyph in a grey circle, a title, one sentence.
private struct Promise: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: Space.base) {
            CircleGlyph(icon: icon)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Type.bodyEmphasis)
                    .foregroundStyle(Label.primary)
                Text(detail)
                    .font(Type.caption)
                    .foregroundStyle(Label.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
