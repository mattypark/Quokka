import SwiftUI
import QuokkaDesign

/// The first screen.
///
/// Images scattered behind the wordmark, which sits through the middle of them rather than
/// above or below -- the overlap is what makes it a composition instead of a logo with a
/// gallery underneath it.
struct OnboardingView: View {
    @Environment(AppState.self) private var state
    let onStart: () -> Void

    var body: some View {
        ZStack {
            Surface.canvas.ignoresSafeArea()

            VStack(spacing: 0) {
                Text("Save what stopped your thumb,\nand turn it into something.")
                    .font(Type.title(21))
                    .foregroundStyle(Label.primary)
                    .multilineTextAlignment(.center)
                    .padding(.top, Space.section)
                    .padding(.horizontal, Space.section)

                Spacer(minLength: 0)

                // Markdown links rather than plain text. The sentence read as though the two
                // documents were reachable long before either one was, which is the version of
                // this that gets cited.
                Text("By continuing you agree to the [Terms](\(Legal.terms)) and [Privacy Policy](\(Legal.privacy)).")
                    .font(Type.caption)
                    .foregroundStyle(Label.dim)
                    .tint(Label.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.section)

                Button {
                    Haptics.shared.saved()
                    onStart()
                } label: {
                    Text("Start")
                        .font(Type.bodyEmphasis)
                        .foregroundStyle(Label.onInverse)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Space.roomy)
                        .background(Surface.inverse, in: Capsule())
                }
                .padding(.horizontal, Space.section)
                .padding(.top, Space.roomy)
                .padding(.bottom, Space.section)
            }

            // Behind the text, in front of the canvas.
            ScatteredGallery(items: state.items, loader: state.loader)
                .allowsHitTesting(false)
                .padding(.horizontal, Space.roomy)
                .padding(.top, 150)
                .padding(.bottom, 190)

            VStack(spacing: Space.base) {
                Wordmark(size: 54)
            }
            .allowsHitTesting(false)
        }
    }
}
