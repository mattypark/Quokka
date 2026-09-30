import SwiftUI
import QuokkaDesign

/// The first screen: the whole page is sky.
///
/// The mark blinks at you, one large line says what the app does, three short promises say
/// how, and one white pill starts it. On a first launch the library is empty, so there is
/// nothing to show but the idea -- which is the point of a first screen anyway.
struct OnboardingView: View {
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            QuokkaMark(size: 76, blinks: true)
                .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
                .padding(.top, Space.section)

            Spacer(minLength: Space.loose)

            VStack(alignment: .leading, spacing: Space.base) {
                // In the hand, untracked: tightening a hand-drawn face makes the letters
                // collide rather than look designed.
                Text("Break down\nany video.")
                    .font(Type.hand(46))
                    .lineSpacing(-6)
                    .foregroundStyle(Label.onSky)
                Text("Save a reel, a TikTok or a YouTube video. Quokka reads what was said and shows you what made it work.")
                    .font(Type.body)
                    .foregroundStyle(Label.onSkySecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Space.loose)

            VStack(spacing: Space.snug) {
                Promise(icon: "square.and.arrow.up", title: "Save from any app", detail: "Share it to Quokka, or paste the link.")
                Promise(icon: "waveform", title: "Get the words", detail: "Transcribed on your phone. Nothing uploaded.")
                Promise(icon: "checkmark.circle", title: "See what worked", detail: "The hook, the pace, the beats, the ask.")
            }

            Spacer(minLength: Space.loose)

            VStack(spacing: Space.base) {
                Button {
                    Haptics.shared.saved()
                    onStart()
                } label: {
                    FilledPill(title: "Get started", tone: .white)
                }
                .buttonStyle(PressStyle())

                // Markdown links rather than plain text, so both documents are one tap away
                // from the sentence that cites them.
                Text("By continuing you agree to the [Terms](\(Legal.terms)) and [Privacy Policy](\(Legal.privacy)).")
                    .font(Type.caption)
                    .foregroundStyle(Label.onSkySecondary)
                    .tint(Label.onSky)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .padding(.bottom, Space.base)
        }
        .padding(.horizontal, Space.gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(SkyBackground().ignoresSafeArea())
    }
}

/// One line of what the app does, in a glass row on the sky.
private struct Promise: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: Space.base) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Label.onSky)
                .frame(width: 40, height: 40)
                .background(Sky.glass, in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(Type.bodyEmphasis)
                    .foregroundStyle(Label.onSky)
                Text(detail)
                    .font(Type.caption)
                    .foregroundStyle(Label.onSkySecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(Space.base)
        .background(Sky.glass, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).stroke(Sky.glassStroke, lineWidth: Stroke.thin))
        .accessibilityElement(children: .combine)
    }
}
