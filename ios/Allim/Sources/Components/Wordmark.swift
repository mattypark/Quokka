import SwiftUI
import AllimDesign

/// The name spelling itself out, one glyph at a time, each landing with a haptic tap, and
/// then resolving into the word it is a romanisation of.
///
/// 알림 is set in the same face rather than a substituted system font: Bagel Fat One is a
/// Korean-designed face and carries full Hangul, which is most of its 1.5 MB. That is the
/// detail that makes the two lines read as one wordmark instead of as a translation.
struct Wordmark: View {
    var text = "ALLIM"
    var native = "알림"
    var size: CGFloat = 46
    var animated = true
    var showsNative = true
    var onComplete: (() -> Void)?

    @State private var revealed = 0
    @State private var nativeShown = false

    private var characters: [Character] { Array(text) }

    var body: some View {
        VStack(spacing: size * 0.16) {
            HStack(spacing: 0) {
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
            // The face already carries generous sidebearings; without negative tracking the
            // word reads as five letters rather than one mark.
            .tracking(-size * 0.012)

            if showsNative {
                Text(native)
                    .font(Type.wordmark(size * 0.42))
                    .foregroundStyle(Label.tertiary)
                    .opacity(nativeShown ? 1 : 0)
                    .animation(Motion.respecting(.easeOut(duration: 0.35)), value: nativeShown)
            }
        }
        // One word to anything reading the screen aloud, not five letters and a translation.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
        .task {
            guard animated, !Motion.reduced else {
                revealed = characters.count
                nativeShown = true
                onComplete?()
                return
            }
            for index in characters.indices {
                try? await Task.sleep(for: .seconds(Motion.glyphInterval))
                revealed = index + 1
                Haptics.shared.glyph(index: index, of: characters.count)
            }
            try? await Task.sleep(for: .seconds(0.12))
            nativeShown = true
            try? await Task.sleep(for: .seconds(0.55))
            onComplete?()
        }
    }
}
