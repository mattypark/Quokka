import Foundation

/// A step on the ladder, ordered safest first.
///
/// The ordering is the whole design. Every rung produces the same `Transcript`, so the app
/// never branches on which one it got -- but they differ enormously in what they cost, what
/// they risk, and how often they break, and the cheapest and safest one that can answer should
/// always be the one that does.
///
/// See `docs/RESEARCH-TRANSCRIPTS.md` for why each rung sits where it does.
public enum TranscriptRung: String, Codable, Sendable, CaseIterable, Comparable {
    /// A video file the user handed over through the share sheet -- from their camera, or
    /// downloaded with Instagram's own Download button or TikTok's Save video, both of which
    /// exist only when the creator enabled them. Free, on device, nothing fetched.
    case sharedFile
    /// The app resolves a post URL to its media, transcribes on device, deletes the media.
    /// Free and private, but fragile: platforms change their page payloads without notice,
    /// which is why the patterns are fetched rather than compiled in.
    case resolveOnDevice
    /// Quokka's worker calls a hosted transcript provider. Robust and paid, and the only rung
    /// where a URL leaves the user's device.
    case hosted

    /// Lower is safer and cheaper. Drives the ladder's walk order.
    var rank: Int {
        switch self {
        case .sharedFile: 0
        case .resolveOnDevice: 1
        case .hosted: 2
        }
    }

    public static func < (lhs: TranscriptRung, rhs: TranscriptRung) -> Bool {
        lhs.rank < rhs.rank
    }

    /// The rung's own answer for the row it produces.
    public var source: TranscriptSource {
        switch self {
        case .sharedFile: .sharedFile
        case .resolveOnDevice: .resolvedOnDevice
        case .hosted: .hosted
        }
    }
}

/// Everything a rung needs to try.
///
/// Carries both a local file and a URL because which one is present is exactly what decides
/// whether rung 0 can answer at all. A share that arrived as a link has no file; a share that
/// arrived as a movie may have no useful URL.
public struct TranscriptRequest: Sendable, Equatable {
    /// The item this is for. Optional so the ladder can be exercised without a database.
    public var itemID: Int64?
    /// The canonical post URL. What rungs 1 and 2 work from.
    public var url: String?
    /// The platform's own id for this post, as the canonicaliser extracted it.
    ///
    /// Carried separately from `url` because the resolver templates address a post by id --
    /// re-parsing it out of the URL inside the resolver would mean two implementations of the
    /// same extraction, and the one in `LinkCanonicaliser` is the tested one.
    public var contentID: String?
    /// An absolute path to media already on this device. What rung 0 works from.
    ///
    /// A path rather than a `URL` so the type stays free of any filesystem assumption and
    /// compares cleanly in tests.
    public var localMediaPath: String?
    public var platform: Platform
    /// BCP-47. Nil means "whatever the transcriber thinks it heard".
    public var preferredLocale: String?

    public init(
        itemID: Int64? = nil,
        url: String? = nil,
        contentID: String? = nil,
        localMediaPath: String? = nil,
        platform: Platform,
        preferredLocale: String? = nil
    ) {
        self.itemID = itemID
        self.url = url
        self.contentID = contentID
        self.localMediaPath = localMediaPath
        self.platform = platform
        self.preferredLocale = preferredLocale
    }
}

/// One rung, behind one call.
///
/// `canAttempt` exists so the ladder can skip a rung without paying for a thrown error. A rung
/// that has no file to read, or whose platform has no resolver rule in the current config, is
/// not a failure -- it is simply not applicable, and the difference matters when the app has to
/// tell someone *why* there is no transcript.
public protocol TranscriptProvider: Sendable {
    var rung: TranscriptRung { get }
    func canAttempt(_ request: TranscriptRequest, config: ResolverConfig) -> Bool
    func transcribe(_ request: TranscriptRequest, config: ResolverConfig) async throws -> Transcript
}

/// Why a rung did not produce a transcript.
///
/// Deliberately specific. "It failed" is useless to a user who could fix it themselves by
/// tapping Download in Instagram, and `.mediaUnreachable` versus `.disabled` is the difference
/// between "try again" and "this will never work".
public enum TranscriptFailure: Error, Sendable, Equatable {
    /// The rung is switched off in the current config.
    case disabled
    /// Nothing in the request this rung can work from.
    case notApplicable
    /// The config carries no rule for this platform.
    case noResolverRule
    /// The media could not be fetched or read.
    case mediaUnreachable(String)
    /// Transcription ran and produced nothing usable. Silence, or a language with no model.
    case producedNothing
    /// The device has no downloaded speech model for this locale and could not get one.
    case localeUnavailable(String)
    /// The network call failed. Carries the status when there was one.
    case transport(Int?)
}

/// One rung's attempt, kept whether it worked or not.
///
/// The record is the product feature. A failure screen that says "Instagram did not serve the
/// media -- open the reel, tap Share, then Download, and share the file here" is worth
/// building; one that says "Transcription failed" is not, and it cannot be written without
/// knowing which rung was tried and what it hit.
public struct TranscriptAttempt: Sendable, Equatable {
    public var rung: TranscriptRung
    public var failure: TranscriptFailure?

    public var succeeded: Bool { failure == nil }

    public init(rung: TranscriptRung, failure: TranscriptFailure? = nil) {
        self.rung = rung
        self.failure = failure
    }
}
