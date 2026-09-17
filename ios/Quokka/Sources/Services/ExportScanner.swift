import Foundation
import QuokkaEngine
import os

/// Reads an Instagram export, from a folder **or straight from the `.zip`**.
///
/// It used to be folder-only, on the reasoning that iOS Files can expand an archive natively
/// and that saved a dependency. That was true and it was still the wrong call: expanding a
/// multi-gigabyte zip is a long-press on a context menu most people have never opened, before
/// the app is involved at all, and it lost more imports than every parsing bug combined.
///
/// There is still no dependency. `ZipArchive` reads the central directory and inflates only
/// the handful of JSON files this scanner wants -- an export is overwhelmingly photos and
/// video, so extracting the whole thing would write gigabytes to a phone to read a few
/// megabytes of it.
///
/// Paths are found by walking rather than by construction. Meta reorganises this export between
/// versions -- `messages/inbox/...` has moved under `your_instagram_activity/` and back -- so a
/// hardcoded path is a guarantee of breaking on some future download.
struct ExportScanner {
    private let logger = Logger(subsystem: "com.matthewpark.quokka", category: "import")

    struct Contents {
        var threads: [InstagramExport.Thread] = []
        var savedCount = 0
        var likedCount = 0
        /// Kept so a second pass can read the files again without re-walking a huge tree.
        var messageFiles: [URL] = []
        var savedFiles: [URL] = []
        var likedFiles: [URL] = []
        /// Set instead of the URL lists when the export was read out of an archive.
        var archive: Archive?

        /// Which entries in a `.zip` hold what, so the second pass does not re-scan the
        /// central directory of a file with a hundred thousand entries in it.
        struct Archive {
            var url: URL
            var messageEntries: [ZipArchive.Entry] = []
            var savedEntries: [ZipArchive.Entry] = []
            var likedEntries: [ZipArchive.Entry] = []
        }

        /// Whether there is anything worth importing. A scan that found nothing is the most
        /// common real failure -- usually the wrong folder, or an export that is still
        /// downloading -- and it needs to be distinguishable from one that found an empty
        /// account.
        public var isEmpty: Bool { threads.isEmpty && savedCount == 0 && likedCount == 0 }
    }

    /// Whether this URL should be read as an archive rather than walked as a folder.
    static func isArchive(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == "zip"
    }

    /// Finds every file worth reading, and summarises the conversations.
    ///
    /// Takes the `.zip` or the unzipped folder. Callers do not branch -- the whole point is
    /// that whichever one the user picked out of Files is the right one.
    func scan(root: URL) -> Contents {
        if Self.isArchive(root) { return scanArchive(root) }
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

        contents.threads = Self.merge(contents.threads)

        logger.info("Scan found \(contents.threads.count) threads, \(contents.savedCount) saved, \(contents.likedCount) liked")
        return contents
    }

    private func scanArchive(_ url: URL) -> Contents {
        var contents = Contents()

        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        guard let zip = try? ZipArchive(url: url) else {
            logger.error("Could not open \(url.lastPathComponent) as an archive")
            return contents
        }
        defer { zip.close() }

        var archive = Contents.Archive(url: url)

        for entry in zip.entries {
            let name = entry.name.lowercased()
            guard name.hasSuffix(".json") else { continue }

            if name.hasPrefix("message_") {
                archive.messageEntries.append(entry)
                if let data = try? zip.data(for: entry),
                   let thread = try? InstagramExport.thread(inMessageFile: data, path: entry.path),
                   thread.shareCount > 0 {
                    contents.threads.append(thread)
                }
            } else if name.contains("saved_posts") || name.contains("saved_collections") {
                archive.savedEntries.append(entry)
                if let data = try? zip.data(for: entry),
                   let shares = try? InstagramExport.shares(inSavedFile: data) {
                    contents.savedCount += shares.count
                }
            } else if name.contains("liked_posts") {
                archive.likedEntries.append(entry)
                if let data = try? zip.data(for: entry),
                   let shares = try? InstagramExport.shares(inLikedFile: data) {
                    contents.likedCount += shares.count
                }
            }
        }

        contents.archive = archive
        contents.threads = Self.merge(contents.threads)
        logger.info("Archive scan found \(contents.threads.count) threads, \(contents.savedCount) saved, \(contents.likedCount) liked")
        return contents
    }

    /// A thread can be split across message_1.json, message_2.json ... so entries are merged
    /// by title; otherwise one conversation appears three times in the picker.
    private static func merge(_ threads: [InstagramExport.Thread]) -> [InstagramExport.Thread] {
        var merged: [String: InstagramExport.Thread] = [:]
        for thread in threads {
            if let existing = merged[thread.title] {
                merged[thread.title] = InstagramExport.Thread(
                    path: existing.path,
                    title: existing.title,
                    participants: Array(Set(existing.participants + thread.participants)).sorted(),
                    shareCount: existing.shareCount + thread.shareCount)
            } else {
                merged[thread.title] = thread
            }
        }
        return merged.values.sorted { $0.shareCount > $1.shareCount }
    }

    /// Reads the shares for one selection.
    func shares(
        from contents: Contents,
        root: URL,
        account: String?,
        includeSaved: Bool,
        includeLiked: Bool
    ) -> [InstagramExport.Share] {
        if let archive = contents.archive {
            return sharesFromArchive(
                archive, account: account, includeSaved: includeSaved, includeLiked: includeLiked)
        }
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

    private func sharesFromArchive(
        _ archive: Contents.Archive,
        account: String?,
        includeSaved: Bool,
        includeLiked: Bool
    ) -> [InstagramExport.Share] {
        let scoped = archive.url.startAccessingSecurityScopedResource()
        defer { if scoped { archive.url.stopAccessingSecurityScopedResource() } }

        guard let zip = try? ZipArchive(url: archive.url) else { return [] }
        defer { zip.close() }

        var shares: [InstagramExport.Share] = []
        for entry in archive.messageEntries {
            guard let data = try? zip.data(for: entry) else { continue }
            shares += (try? InstagramExport.shares(inMessageFile: data, only: account)) ?? []
        }
        if includeSaved {
            for entry in archive.savedEntries {
                guard let data = try? zip.data(for: entry) else { continue }
                shares += (try? InstagramExport.shares(inSavedFile: data)) ?? []
            }
        }
        if includeLiked {
            for entry in archive.likedEntries {
                guard let data = try? zip.data(for: entry) else { continue }
                shares += (try? InstagramExport.shares(inLikedFile: data)) ?? []
            }
        }
        return shares
    }
}
