import Foundation
import QuokkaEngine

/// Every word in the intro, in one place.
///
/// Copy lives here rather than inside the views so a wording change is a one-file diff and the
/// views stay about layout. The order of this array is the order of the flow, and the count is
/// what the progress indicator divides by.
enum OnboardingScript {

    static let steps: [OnboardingStep] = [
        OnboardingStep(
            id: .welcome,
            kind: .statement,
            title: "Save what stopped your thumb,\nand turn it into something.",
            helper: nil,
            cta: "Get started"
        ),

        OnboardingStep(
            id: .craft,
            kind: .single([
                .init("video", "Short-form video"),
                .init("photo", "Photography"),
                .init("design", "Design"),
                .init("writing", "Writing"),
                .init("music", "Music"),
                .init("collecting", "Just collecting, for now")
            ]),
            title: "What do you make?",
            helper: "So the library leads with the work you are actually doing.",
            cta: "Continue"
        ),

        OnboardingStep(
            id: .platforms,
            // Built from the real cases rather than a hand-typed list, so this screen cannot
            // offer a platform the canonicaliser does not recognise. `.web` is left out: it is
            // the fallback for everything else, not somewhere a person saves from on purpose.
            kind: .multi(
                Platform.allCases.filter { $0 != .web }.map(OnboardingStep.Choice.init),
                minimum: 1
            ),
            title: "Where do you save from?",
            helper: "Pick as many as you use. You can save from anywhere with a share sheet either way.",
            cta: "Continue"
        ),

        OnboardingStep(
            id: .interests,
            kind: .multi([
                .init("hooks", "Hooks"),
                .init("editing", "Editing"),
                .init("lighting", "Lighting"),
                .init("storytelling", "Storytelling"),
                .init("humour", "Humour"),
                .init("fashion", "Fashion"),
                .init("food", "Food"),
                .init("travel", "Travel"),
                .init("fitness", "Fitness"),
                .init("design", "Design"),
                .init("music", "Music"),
                .init("business", "Business")
            ], minimum: 3),
            title: "What are you collecting?",
            helper: "Three or more. These become the first tags on your library.",
            cta: "Continue"
        ),

        OnboardingStep(
            id: .intent,
            kind: .single([
                .init("scripts", "Scripts I can actually shoot",
                      detail: "Turn saves into a hook and a body you can read off a phone."),
                .init("library", "A library I can search",
                      detail: "Everything you saved, sorted by who made it."),
                .init("today", "Something to make today",
                      detail: "One idea a day, off the pile you already built.")
            ]),
            title: "What do you want out of it?",
            helper: nil,
            cta: "Continue"
        ),

        OnboardingStep(
            id: .teachShareSheet,
            kind: .teach([
                "Find a post you like, in any app.",
                "Tap Share.",
                "Pick Quokka. That is the whole thing -- it files itself."
            ]),
            title: "Saving takes one tap.",
            helper: "Instagram, TikTok, YouTube, Pinterest, X, Reddit. Quokka takes the link, finds the thumbnail, and sorts it on its own.",
            cta: "Got it"
        ),

        OnboardingStep(
            id: .teachDownload,
            // The beat nextsessions/FRONTEND-ASKS.md section 5 asks for, verbatim in intent:
            // "Rung 1 is not code -- it is this screen." A reel the creator allowed you to
            // download carries its own audio, which is the fastest and most reliable transcript
            // there is. The only thing in the way is not knowing the button exists.
            kind: .teach([
                "On a reel, tap Share, then **Download**. TikTok calls it **Save video**.",
                "It lands in your camera roll.",
                "Share that file into Quokka and the words come out in seconds."
            ]),
            title: "One more, for the words.",
            helper: "Quokka can pull the script out of a video. It is fastest when the creator allowed the download.",
            cta: "Got it"
        ),

        OnboardingStep(
            id: .finish,
            kind: .finish,
            title: "That is everything.",
            helper: nil,
            cta: "Start saving"
        )
    ]

    /// Where the two legal links point. The marketing site owns the pages.
    static let termsURL = URL(string: "https://quokka.app/terms")!
    static let privacyURL = URL(string: "https://quokka.app/privacy")!
}
