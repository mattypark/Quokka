import Foundation
import AllimEngine
import os

/// Walks an unzipped Instagram export on disk.
///
/// The app deliberately does not unzip anything. iOS Files can expand a zip natively with a
/// long-press, which means no archive dependency, no unbounded memory spike on a multi-gigabyte
/// export, and one less thing to get wrong. The user unzips; Allim reads the folder.
///
/// Paths are found by walking rather than by construction. Meta reorganises this export between
/// versions -- `messages/inbox/...` has moved under `your_instagram_activity/` and back -- so a
/// hardcoded path is a guarantee of breaking on some future download.
struct ExportScanner {
    private let logger = Logger(subsystem: "com.matthewpark.allim", category: "import")

    struct Contents {
        var threads: [InstagramExport.Thread] = []
        var savedCount = 0
        var likedCount = 0
        /// Kept so a second pass can read the files again without re-walking a huge tree.
        var messageFiles: [URL] = []
        var savedFiles: [URL] = []
        var likedFiles: [URL] = []
    }

    /// Finds every file worth reading, and summarises the conversations.
    func scan(root: URL) -> Contents {
        var contents = Contents()

        // A security-scoped URL from the document picker must be opened before it can be read,
        // and balanced afterwards or the sandbox leaks the grant.
        let scoped = root.startAccessingSecurityScopedResource()
        defer { if scoped { root.stopAccessingSecurityScopedResource() } }

        guard let walker = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return contents }

        for case let url as URL in walker {
            let name = url.lastPathComponent.lowercased()
            guard name.hasSuffix(".json") else { continue }

            if name.hasPrefix("message_") {
                contents.messageFiles.append(url)
                if let data = try? Data(contentsOf: url),
                   let thread = try? InstagramExport.thread(inMessageFile: data, path: url.path),
                   thread.shareCount > 0 {
                    contents.threads.append(thread)
                }
            } else if name.contains("saved_posts") || name.contains("saved_collections") {
                contents.savedFiles.append(url)
                if let data = try? Data(contentsOf: url),
                   let shares = try? InstagramExport.shares(inSavedFile: data) {
                    contents.savedCount += shares.count
                }
            } else if name.contains("liked_posts") {
                contents.likedFiles.append(url)
                if let data = try? Data(contentsOf: url),
                   let shares = try? InstagramExport.shares(inLikedFile: data) {
                    contents.likedCount += shares.count
                }
            }
        }

        // A thread can be split across message_1.json, message_2.json ... so entries are merged
        // by title; otherwise one conversation appears three times in the picker.
        var merged: [String: InstagramExport.Thread] = [:]
        for thread in contents.threads {
            if let existing = merged[thread.title] {
                merged[thread.title] = InstagramExport.Thread(
                    path: existing.path,
                    title: existing.title,
                    participants: Array(Set(existing.participants + thread.participants)).sorted(),
                    shareCount: existing.shareCount + thread.shareCount
                )
            } else {
                merged[thread.title] = thread
            }
        }
        contents.threads = merged.values.sorted { $0.shareCount > $1.shareCount }

        logger.info("Scan found \(contents.threads.count) threads, \(contents.savedCount) saved, \(contents.likedCount) liked")
        return contents
    }

    /// Reads the shares for one selection.
    func shares(
        from contents: Contents,
        root: URL,
        account: String?,
        includeSaved: Bool,
        includeLiked: Bool
    ) -> [InstagramExport.Share] {
        let scoped = root.startAccessingSecurityScopedResource()
        defer { if scoped { root.stopAccessingSecurityScopedResource() } }

        var shares: [InstagramExport.Share] = []

        for url in contents.messageFiles {
            guard let data = try? Data(contentsOf: url) else { continue }
            shares += (try? InstagramExport.shares(inMessageFile: data, only: account)) ?? []
        }
        if includeSaved {
            for url in contents.savedFiles {
                guard let data = try? Data(contentsOf: url) else { continue }
                shares += (try? InstagramExport.shares(inSavedFile: data)) ?? []
            }
        }
        if includeLiked {
            for url in contents.likedFiles {
                guard let data = try? Data(contentsOf: url) else { continue }
                shares += (try? InstagramExport.shares(inLikedFile: data)) ?? []
            }
        }
        return shares
    }
}
