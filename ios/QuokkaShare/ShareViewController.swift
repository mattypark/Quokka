import UIKit
import SwiftUI
import UniformTypeIdentifiers
import QuokkaEngine
import QuokkaImaging
import os

/// The daily capture path, and the only part of Quokka most saves ever touch.
///
/// Three rules govern everything here, all of them consequences of running as an app
/// extension rather than as the app:
///
/// 1. **No network.** Extensions are killed for being slow, and a thumbnail fetch against a
///    cold cellular connection is unbounded. Enrichment belongs to the app.
/// 2. **No full bitmaps.** The memory ceiling is ~120 MB and a decoded photo is tens of MB.
/// 3. **Write and get out.** The target is under 400 ms from tap to dismissal.
///
/// So this writes a deliberately dumb record -- what was handed over, plus the type
/// identifiers it arrived with -- and lets the app do the thinking.
final class ShareViewController: UIViewController {
    private let logger = Logger(subsystem: "com.matthewpark.quokka", category: "share")
    private var hosting: UIHostingController<ShareConfirmation>?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        presentConfirmation()

        Task {
            let outcome = await capture()
            await MainActor.run { finish(outcome) }
        }
    }

    // MARK: - Capture

    private enum Outcome {
        case saved(platform: Platform?, carriesVideo: Bool)
        case nothingUsable
    }

    private func capture() async -> Outcome {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else { return .nothingUsable }
        guard let directory = ShareInbox.directory() else {
            logger.error("No App Group container -- check the entitlement on both targets")
            return .nothingUsable
        }

        var rawURL: String?
        var rawText: String?
        var imageFilename: String?
        var movieFilename: String?
        var probes: [ProviderProbe] = []
        var probeIndex = 0

        for item in items {
            for provider in item.attachments ?? [] {
                // The probe, recorded before anything is loaded: some providers advertise a
                // type they then fail to hand over, and the advertisement is itself the
                // finding worth keeping.
                probes.append(ProviderProbe(index: probeIndex, typeIdentifiers: provider.registeredTypeIdentifiers))
                probeIndex += 1

                if rawURL == nil, provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    rawURL = await loadURL(from: provider)
                }
                if rawText == nil, provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    rawText = await loadText(from: provider)
                }
                if imageFilename == nil, provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    imageFilename = await storeImage(from: provider, in: directory)
                }
                // The Info.plist has declared movie support since the first commit, but nothing
                // ever loaded one -- so a shared video was silently dropped. This branch is the
                // entire on-device transcription path: a user saves a reel to Photos, shares
                // the file, and Quokka transcribes their own file with nothing fetched.
                if movieFilename == nil, provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                    movieFilename = await storeMovie(from: provider, in: directory)
                }
            }
        }

        // A share with no link is still worth keeping -- a screenshot, or a video straight
        // out of Photos, is exactly the kind of thing this app exists to hold.
        guard rawURL != nil || rawText != nil || imageFilename != nil || movieFilename != nil else {
            return .nothingUsable
        }

        let record = ShareInboxRecord(
            rawURL: rawURL,
            rawText: rawText,
            imageFilename: imageFilename,
            movieFilename: movieFilename,
            probe: probes
        )

        do {
            let data = try ShareInbox.encoder.encode(record)
            let url = ShareInbox.recordURL(for: record.id, in: directory)

            // Coordinated: the app may be draining the inbox at this exact moment, and an
            // uncoordinated write can hand it a truncated file that silently decodes to
            // nothing and loses the save.
            var coordinationError: NSError?
            var writeError: Error?
            NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { writeURL in
                do { try data.write(to: writeURL, options: .atomic) } catch { writeError = error }
            }
            if let coordinationError { throw coordinationError }
            if let writeError { throw writeError }
        } catch {
            logger.error("Could not write the inbox record: \(error.localizedDescription)")
            return .nothingUsable
        }

        let platform = record.linkCandidate
            .flatMap(LinkCanonicaliser.canonicalise)?
            .platform
        return .saved(platform: platform, carriesVideo: movieFilename != nil)
    }

    // Two typed loaders rather than one generic one. `NSSecureCoding` is not Sendable, so
    // handing it across the continuation is a data race; converting to String inside the
    // callback and sending that instead is both safe and simpler at the call site.

    private func loadURL(from provider: NSItemProvider) async -> String? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { value, error in
                if let error { self.logger.error("url load failed: \(error.localizedDescription)") }
                continuation.resume(returning: (value as? URL)?.absoluteString)
            }
        }
    }

    private func loadText(from provider: NSItemProvider) async -> String? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { value, error in
                if let error { self.logger.error("text load failed: \(error.localizedDescription)") }
                continuation.resume(returning: value as? String)
            }
        }
    }

    /// Downsamples straight from the provider's file, never through a `UIImage`.
    private func storeImage(from provider: NSItemProvider, in directory: URL) async -> String? {
        let loaded: Thumbnail? = await withCheckedContinuation { continuation in
            _ = provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, error in
                if let error { self.logger.error("image load failed: \(error.localizedDescription)") }
                guard let url else { continuation.resume(returning: nil); return }
                // The file is deleted the moment this closure returns, so the downsample has
                // to happen here rather than after.
                continuation.resume(returning: ImageDownsampler.thumbnail(fromFileAt: url))
            }
        }

        guard let loaded else { return nil }
        let filename = "\(UUID().uuidString).\(loaded.format)"
        do {
            try loaded.data.write(to: directory.appendingPathComponent(filename), options: .atomic)
            return filename
        } catch {
            logger.error("Could not write the thumbnail: \(error.localizedDescription)")
            return nil
        }
    }

    /// Copies a shared video into the inbox.
    ///
    /// A file copy, never a read into memory. Extensions are killed at roughly 120 MB and a
    /// phone video is routinely larger than that, so `FileManager.copyItem` streams it while
    /// `Data(contentsOf:)` would be an instant jetsam. Nothing here decodes a single frame.
    private func storeMovie(from provider: NSItemProvider, in directory: URL) async -> String? {
        await withCheckedContinuation { continuation in
            _ = provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                if let error { self.logger.error("movie load failed: \(error.localizedDescription)") }
                guard let url else { continuation.resume(returning: nil); return }

                // The temp file is deleted the moment this closure returns, so the copy has to
                // happen here rather than after.
                let filename = "\(UUID().uuidString).\(url.pathExtension.isEmpty ? "mov" : url.pathExtension)"
                let destination = directory.appendingPathComponent(filename)
                do {
                    try FileManager.default.copyItem(at: url, to: destination)
                    continuation.resume(returning: filename)
                } catch {
                    self.logger.error("Could not copy the video: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    // MARK: - Confirmation

    private func presentConfirmation() {
        // Video shares take seconds rather than milliseconds -- there is a file to copy -- so
        // the first frame has to already say so. Guessed from the attachments before anything
        // is loaded, because by the time loading confirms it the moment has passed.
        let hosting = UIHostingController(
            rootView: ShareConfirmation(state: .working, platform: nil, carriesVideo: expectsVideo)
        )
        hosting.view.backgroundColor = .clear
        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        hosting.didMove(toParent: self)
        self.hosting = hosting
    }

    /// Whether the incoming share looks like a video, known before anything is loaded.
    private var expectsVideo: Bool {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else { return false }
        return items.contains { item in
            (item.attachments ?? []).contains {
                $0.hasItemConformingToTypeIdentifier(UTType.movie.identifier)
            }
        }
    }

    private func finish(_ outcome: Outcome) {
        switch outcome {
        case .saved(let platform, let carriesVideo):
            ShareHaptics.saved()
            hosting?.rootView = ShareConfirmation(
                state: .saved,
                platform: platform,
                carriesVideo: carriesVideo,
                onOpen: { [weak self] in self?.openApp(preview: false) },
                onDone: { [weak self] in self?.close() }
            )
            // A save with choices on it does not auto-dismiss. Closing the sheet under someone
            // reaching for "Open in app" is worse than making them tap Done.
        case .nothingUsable:
            ShareHaptics.rejected()
            hosting?.rootView = ShareConfirmation(
                state: .rejected, platform: nil, onDone: { [weak self] in self?.close() }
            )
            // Nothing to decide here, so it gets out of the way on its own.
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.4))
                self.close()
            }
        }
    }

    private func close() {
        extensionContext?.completeRequest(returningItems: nil)
    }

    /// Hands off to the app.
    ///
    /// `extensionContext.open` is the sanctioned route out of a share extension;
    /// `UIApplication.shared` is unavailable in one and reaching for it through the responder
    /// chain is the trick Apple rejects apps for.
    private func openApp(preview: Bool) {
        guard let url = URL(string: preview ? "quokka://preview" : "quokka://open") else { return }
        extensionContext?.open(url) { [weak self] opened in
            if !opened { self?.logger.error("Could not open the app") }
            self?.close()
        }
    }
}
