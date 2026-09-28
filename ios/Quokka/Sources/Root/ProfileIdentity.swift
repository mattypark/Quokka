import Foundation
import Observation
import UIKit
import QuokkaImaging

/// The name and picture on the profile screen.
///
/// Local only. Quokka has no accounts, so this is a label a person puts on their own library,
/// not an identity anyone else sees -- which is why it lives in defaults and a file rather than
/// in the database next to the things they saved.
@MainActor
@Observable
final class ProfileIdentity {
    private static let nameKey = "quokkaProfileName"

    var name: String {
        didSet { UserDefaults.standard.set(name, forKey: Self.nameKey) }
    }

    private(set) var avatar: UIImage?

    init() {
        name = UserDefaults.standard.string(forKey: Self.nameKey) ?? ""
        avatar = Self.avatarURL.flatMap { UIImage(contentsOfFile: $0.path) }
    }

    /// What to show when no name has been set.
    var displayName: String { name.isEmpty ? "You" : name }

    /// Downsampled on the way in. A picker hands over a full-resolution photo, and a 24pt tab
    /// bar glyph has no use for 48 MB of decoded bitmap.
    func setAvatar(_ data: Data) {
        guard let thumbnail = ImageDownsampler.thumbnail(from: data),
              let url = Self.avatarURL
        else { return }
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try thumbnail.data.write(to: url, options: .atomic)
            avatar = UIImage(data: thumbnail.data)
        } catch {
            // A picture that did not save is not worth an alert; the initial stays.
            print("[Quokka] Avatar not saved: \(error.localizedDescription)")
        }
    }

    /// Application Support, beside the database: the picture is the person's own data and must
    /// not be purged the way Caches can be.
    private static var avatarURL: URL? {
        try? FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("profile", isDirectory: true)
            .appendingPathComponent("avatar")
    }
}
