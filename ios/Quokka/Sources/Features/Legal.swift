import Foundation

/// The two URLs Apple requires, in one place.
///
/// The privacy policy has to be reachable from **two** places: the App Store Connect metadata
/// field and inside the app itself. Most submissions do one and get cited for it. Keeping both
/// links pointed at one constant is what stops the in-app one rotting after the site moves.
enum Legal {
    static let privacy = URL(string: "https://quokka.app/privacy")!
    static let terms = URL(string: "https://quokka.app/terms")!
    static let support = URL(string: "https://quokka.app/support")!
}
