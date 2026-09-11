import Foundation

/// What the share extension observed about one attachment.
///
/// This exists for a specific open question: whether Instagram, Pinterest and X hand a
/// thumbnail to the share sheet even though they serve none to an HTTP client. If they do,
/// three "unreachable" platforms become reachable and the fallback tile stops being their
/// permanent state. Recording it in the row rather than to the console means the answer
/// survives to be read in the app, on a real device, where those apps actually exist.
public struct ProviderProbe: Codable, Sendable, Equatable {
    public let index: Int
    public let typeIdentifiers: [String]

    public init(index: Int, typeIdentifiers: [String]) {
        self.index = index
        self.typeIdentifiers = typeIdentifiers
    }
}

/// One save, as written by the share extension before the app has seen it.
///
/// Deliberately dumb. The extension does no network, no canonicalisation and no image
/// decoding beyond a downsample -- it writes what it was handed and gets out, because it runs
/// under a hard memory cap and is killed for being slow.
public struct ShareInboxRecord: Codable, Sendable, Equatable {
    public let id: UUID
    public let receivedAt: Date
    public let rawURL: String?
    public let rawText: String?
    /// Filename, relative to the inbox directory, of an image the share payload carried.
    public let imageFilename: String?
    /// Filename of a **video file** the share payload carried.
    ///
    /// This is the only lawful door to a transcript. No platform's share sheet hands over a
    /// video for a link -- it is always a URL, and every sanctioned API refuses the media for
    /// a video the user does not own. What does work is the user saving the video to Photos
    /// first and sharing the file: then it is their file, handed over by the system, and
    /// transcription happens on device with nothing fetched and nothing circumvented.
    public let movieFilename: String?
    public let probe: [ProviderProbe]

    public init(
        id: UUID = UUID(),
        receivedAt: Date = Date(),
        rawURL: String?,
        rawText: String?,
        imageFilename: String? = nil,
        movieFilename: String? = nil,
        probe: [ProviderProbe] = []
    ) {
        self.id = id
        self.receivedAt = receivedAt
        self.rawURL = rawURL
        self.rawText = rawText
        self.imageFilename = imageFilename
        self.movieFilename = movieFilename
        self.probe = probe
    }

    /// The best string to canonicalise from. A URL attachment is authoritative; the text is a
    /// fallback because several apps send the link only inside a sentence.
    ///
    /// YouTube in particular arrives as `public.plain-text` rather than `public.url`, which is
    /// the most common way a share extension silently drops a save.
    public var linkCandidate: String? {
        if let rawURL, !rawURL.isEmpty { return rawURL }
        return rawText
    }

    /// A share carrying a video file rather than a link. These are the ones that can be
    /// transcribed, because the user handed over their own file.
    public var carriesMovie: Bool { movieFilename != nil }
}

/// The App Group directory both processes agree on.
///
/// The App Group holds the inbox and nothing else. The database lives in Application Support
/// in the app's own container, because iOS terminates a suspended app that is holding a file
/// lock inside a shared container -- the 0xDEAD10CC crash -- and a WAL-mode SQLite connection
/// is exactly that kind of lock.
public enum ShareInbox {
    public static let appGroupID = "group.com.matthewpark.quokka"

    public static func directory(fileManager: FileManager = .default) -> URL? {
        guard let container = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return nil
        }
        let inbox = container.appendingPathComponent("Inbox", isDirectory: true)
        try? fileManager.createDirectory(at: inbox, withIntermediateDirectories: true)
        return inbox
    }

    public static func recordURL(for id: UUID, in directory: URL) -> URL {
        directory.appendingPathComponent("\(id.uuidString).json", isDirectory: false)
    }

    /// Records waiting to be drained, oldest first so import order matches save order.
    public static func pendingRecords(in directory: URL, fileManager: FileManager = .default) -> [URL] {
        let contents = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        return contents
            .filter { $0.pathExtension == "json" }
            .sorted { a, b in
                let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                return (da ?? .distantPast) < (db ?? .distantPast)
            }
    }

    /// ISO-8601 *with fractional seconds*.
    ///
    /// Foundation's stock `.iso8601` strategy truncates to whole seconds, so a timestamp does
    /// not survive a round-trip. That matters during an Instagram import, where thousands of
    /// records are written in a burst and whole-second stamps would collapse an entire batch
    /// onto one instant, destroying the order they were saved in.
    /// A value type, not `ISO8601DateFormatter` -- the class is not Sendable and cannot be a
    /// shared `static let` under strict concurrency.
    private static let iso8601 = Date.ISO8601FormatStyle(includingFractionalSeconds: true)

    public static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(iso8601.format(date))
        }
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    public static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            do {
                return try iso8601.parse(text)
            } catch {
                throw DecodingError.dataCorrupted(
                    .init(codingPath: decoder.codingPath, debugDescription: "Bad date: \(text)")
                )
            }
        }
        return d
    }()
}
