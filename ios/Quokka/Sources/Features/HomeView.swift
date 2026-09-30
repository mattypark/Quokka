import SwiftUI
import QuokkaDesign
import QuokkaEngine
import QuokkaImaging

/// Home: what you have saved, and what it can tell you.
///
/// The sky carries the mark, the date and three counts -- saved, transcribed, waiting -- as
/// rings, which is the part borrowed from Nudgy. Under it, on paper, is the work: the videos
/// whose transcripts are ready to break down, the ones still waiting for words, and the latest
/// saves.
struct HomeView: View {
    @Environment(AppState.self) private var state
    @Binding var path: NavigationPath
    var scrollToTop = 0
    var onImport: () -> Void = {}
    var onSettings: () -> Void = {}
    var onLibrary: () -> Void = {}

    @State private var pulse = AppState.Pulse()
    @State private var ready: [Item] = []
    @State private var waiting: [Item] = []
    @State private var pasteResult: PasteResult?

    private enum PasteResult { case saved, notALink }

    var body: some View {
        NavigationStack(path: $path) {
            GeometryReader { outer in
                ScrollViewReader { reader in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: Space.loose) {
                            header(topInset: outer.safeAreaInsets.top).id(Self.top)

                            if let failure = state.storeFailure {
                                EmptyNote(title: "The library could not be opened", detail: failure)
                            } else if state.total == 0 {
                                EmptyNote(
                                    title: "Save a video to break it down",
                                    detail: "Share a reel, a TikTok or a YouTube video to Quokka from any app, or paste a link above.")
                            } else {
                                if !ready.isEmpty { readySection }
                                if !waiting.isEmpty { waitingSection }
                                recentSection
                            }
                        }
                        .padding(.bottom, Grid.bottomInset)
                    }
                    // The sky runs up under the status bar, the way Nudgy's does; the header pads
                    // itself down by the inset instead.
                    .ignoresSafeArea(edges: .top)
                    .onChange(of: scrollToTop) {
                        withAnimation(Motion.respecting(.easeOut(duration: 0.3))) {
                            reader.scrollTo(Self.top, anchor: .top)
                        }
                    }
                }
            }
            .background(Surface.canvas)
            .toolbar(.hidden, for: .navigationBar)
            .quokkaRoutes()
        }
        .task { refresh() }
        .onChange(of: state.total) { refresh() }
        .onChange(of: path.count) { _, depth in if depth == 0 { refresh() } }
        .task { await openForScreenshot() }
    }

    private static let top = "top"

    // MARK: - Sky

    private func header(topInset: CGFloat) -> some View {
        VStack(spacing: Space.loose) {
            HStack {
                QuokkaMark(size: 32, blinks: true)
                Spacer()
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(Type.hand(21))
                    .foregroundStyle(Label.onSky)
                Spacer()
                CircleButton(icon: "gearshape.fill", label: "Settings", onSky: true, action: onSettings)
            }

            HStack(spacing: 0) {
                PulseRing(value: pulse.saved, fraction: 1, label: "Saved")
                PulseRing(value: pulse.transcribed, fraction: fraction(pulse.transcribed), label: "Transcribed")
                PulseRing(value: pulse.waiting, fraction: fraction(pulse.waiting), label: "Waiting")
            }

            HStack(spacing: Space.base) {
                Button(action: paste) {
                    GlassPill(title: pasteTitle, icon: pasteResult == .saved ? "checkmark" : "link")
                }
                .buttonStyle(PressStyle())
                Button(action: onImport) {
                    GlassPill(title: "Import", icon: "square.and.arrow.down")
                }
                .buttonStyle(PressStyle())
            }
        }
        .padding(.horizontal, Space.gutter)
        .padding(.top, topInset + Space.snug)
        .padding(.bottom, Space.loose)
        .skyHeader()
    }

    private var pasteTitle: String {
        switch pasteResult {
        case .saved: "Saved"
        case .notALink: "No link copied"
        case nil: "Paste a link"
        }
    }

    private func fraction(_ part: Int) -> Double {
        pulse.saved == 0 ? 0 : Double(part) / Double(pulse.saved)
    }

    // MARK: - Sections

    private var readySection: some View {
        VStack(alignment: .leading, spacing: Space.base) {
            SectionLabel(text: "Ready to break down", trailing: "\(ready.count)")
            ForEach(ready) { item in
                if let id = item.id {
                    NavigationLink(value: Route.item(id)) {
                        BreakdownRow(item: item, breakdown: state.breakdown(forItem: id), loader: state.loader)
                    }
                    .buttonStyle(PressStyle())
                }
            }
        }
        .padding(.horizontal, Space.gutter)
    }

    private var waitingSection: some View {
        VStack(alignment: .leading, spacing: Space.base) {
            SectionLabel(text: "Needs a transcript", trailing: "\(waiting.count)")
            Card(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(waiting.prefix(5).enumerated()), id: \.element.id) { index, item in
                        if let id = item.id {
                            WaitingRow(
                                item: item,
                                queued: state.isTranscriptQueued(id),
                                failure: state.transcriptFailure(id),
                                loader: state.loader,
                                onRequest: {
                                    state.requestTranscript(id)
                                    refresh()
                                },
                                onOpen: { path.append(Route.item(id)) })
                            if index < min(waiting.count, 5) - 1 {
                                Rectangle().fill(Surface.hairline).frame(height: Stroke.thin)
                                    .padding(.leading, 76)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, Space.gutter)
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: Space.base) {
            HStack {
                SectionLabel(text: "Recently saved")
                Button("See all", action: onLibrary)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Sky.accent)
            }
            .padding(.horizontal, Space.gutter)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.snug) {
                    ForEach(state.items.prefix(12)) { item in
                        TileLink(item: item, loader: state.loader)
                            .frame(width: 118, height: 158)
                    }
                }
                .padding(.horizontal, Space.gutter)
            }
        }
    }

    // MARK: - Work

    private func refresh() {
        pulse = state.pulse()
        ready = state.transcribedItems(limit: 8)
        waiting = state.untranscribedVideos(limit: 20)
    }

    private func paste() {
        let copied = UIPasteboard.general.url?.absoluteString ?? UIPasteboard.general.string ?? ""
        let saved = state.saveLink(copied)
        pasteResult = saved ? .saved : .notALink
        if saved { Haptics.shared.saved() } else { Haptics.shared.rejected() }
        refresh()
        Task {
            try? await Task.sleep(for: .seconds(1.8))
            pasteResult = nil
        }
    }

    /// Pushes straight into a breakdown, for screenshot runs. DEBUG-only so it cannot ship.
    private func openForScreenshot() async {
        #if DEBUG
        guard UserDefaults.standard.string(forKey: "quokkaScreen") == "item", path.isEmpty else { return }
        // Waits a beat for the sample transcripts to be planted on first launch.
        try? await Task.sleep(for: .milliseconds(600))
        let target = state.transcribedItems(limit: 1).first
            ?? state.items.first(where: { $0.thumbnailState == .stored })
            ?? state.items.first
        if let id = target?.id { path.append(Route.item(id)) }
        #endif
    }
}

/// One count on the sky, inside a ring that fills with its share of everything saved.
private struct PulseRing: View {
    let value: Int
    let fraction: Double
    let label: String

    var body: some View {
        VStack(spacing: Space.snug) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.22), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: max(min(fraction, 1), value > 0 ? 0.04 : 0))
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(CountBadge.abbreviated(value))
                    .font(Type.numeral(30))
                    .foregroundStyle(Label.onSky)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .padding(.horizontal, Space.snug)
            }
            .frame(width: 92, height: 92)
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Label.onSkySecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) \(label.lowercased())")
    }
}

/// A video whose transcript is in, with the gist of its breakdown.
private struct BreakdownRow: View {
    let item: Item
    let breakdown: Breakdown?
    let loader: ThumbnailLoader?

    var body: some View {
        Card(padding: Space.base) {
            HStack(spacing: Space.base) {
                ItemTile(item: item, loader: loader)
                    .frame(width: 64, height: 84)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(item.author ?? item.title ?? item.platform.displayName)
                        .font(Type.bodyEmphasis)
                        .foregroundStyle(Label.primary)
                        .lineLimit(1)
                    if let breakdown {
                        Text("“\(breakdown.hook.text)”")
                            .font(Type.caption)
                            .foregroundStyle(Label.secondary)
                            .lineLimit(2)
                        CheckDots(checks: breakdown.checks)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Label.dim)
            }
        }
    }
}

/// One dot per check, blue where it passed -- the breakdown at a glance.
struct CheckDots: View {
    let checks: [Breakdown.Check]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(checks) { check in
                Capsule()
                    .fill(check.passed ? Sky.accent : Surface.elevated)
                    .frame(width: 14, height: 5)
            }
            Text("\(checks.filter(\.passed).count)/\(checks.count)")
                .font(Type.meta(12))
                .foregroundStyle(Label.secondary)
                .padding(.leading, 2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(checks.filter(\.passed).count) of \(checks.count) checks passed")
    }
}

/// A video with no words yet, and the one thing to do about it.
private struct WaitingRow: View {
    let item: Item
    let queued: Bool
    let failure: String?
    let loader: ThumbnailLoader?
    let onRequest: () -> Void
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: Space.base) {
            Button(action: onOpen) {
                HStack(spacing: Space.base) {
                    ItemTile(item: item, loader: loader)
                        .frame(width: 48, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.author ?? item.title ?? item.platform.displayName)
                            .font(Type.bodyEmphasis)
                            .foregroundStyle(Label.primary)
                            .lineLimit(1)
                        Text(status)
                            .font(Type.caption)
                            .foregroundStyle(Label.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if queued {
                ProgressView().controlSize(.small).tint(Sky.accent)
            } else if failure == nil {
                Button(action: onRequest) {
                    Text("Transcribe")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Sky.accent)
                        .padding(.horizontal, Space.base)
                        .frame(height: 32)
                        .background(Sky.tint, in: Capsule())
                }
                .buttonStyle(PressStyle())
            }
        }
        .padding(.horizontal, Space.base)
        .padding(.vertical, Space.snug)
    }

    private var status: String {
        if queued { return "Reading the audio…" }
        if failure != nil { return "Couldn’t read this one — open for why" }
        return item.platform.displayName
    }
}
