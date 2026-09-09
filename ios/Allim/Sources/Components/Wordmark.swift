import SwiftUI
import AllimDesign

/// The name spelling itself out, one glyph at a time, each landing with a haptic tap.
///
/// This is the app's whole first impression, so it is a component rather than something
/// inlined into the splash: the same treatment is reused as an empty-state mark.
struct Wordmark: View {
    var text = "ALLIM"
    var size: CGFloat = 44
    var animated = true
    var onComplete: (() -> Void)?

    @State private var revealed = 0

    private var characters: [Character] { Array(text) }

    var body: some View {
        HStack(spacing: size * 0.06) {
            ForEach(Array(characters.enumerated()), id: \.offset) { index, character in
                Text(String(character))
                    .font(Type.wordmark(size))
                    .foregroundStyle(Label.primary)
                    .opacity(index < revealed ? 1 : 0)
                    // Rising rather than fading in place: the letters read as arriving,
                    // which is the metaphor the whole app runs on.
                    .offset(y: index < revealed ? 0 : size * 0.12)
                    .animation(Motion.respecting(.easeOut(duration: 0.24)), value: revealed)
            }
        }
        // The wordmark is one word, not five letters, to anything reading the screen aloud.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
        .task {
            guard animated, !Motion.reduced else {
                revealed = characters.count
                onComplete?()
                return
            }
            for index in characters.indices {
                try? await Task.sleep(for: .seconds(Motion.glyphInterval))
                revealed = index + 1
                Haptics.shared.glyph(index: index, of: characters.count)
            }
            try? await Task.sleep(for: .seconds(0.45))
            onComplete?()
        }
    }
}
