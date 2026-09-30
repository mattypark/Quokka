import SwiftUI
import QuokkaDesign
import QuokkaEngine
import QuokkaImaging

/// One saved video, broken down -- the screen the app is built around.
///
/// Three tabs, the way Nudgy lays a recording out: **Breakdown** (what worked, the hook, the
/// pace, the beats, the ending), **Transcript** (the words, timed), and **Save** (playlists and
/// more from the same creator). Everything on the Breakdown tab is read out of the transcript
/// by `Breakdown` -- rules on the phone, the same answer every time, with the evidence shown.
struct ItemDetailView: View {
    let itemID: Int64

    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var item: Item?
    @State private var transcript: Transcript?
    @State private var breakdown: Breakdown?
    @State private var queued = false
    @State private var failure: String?
    @State private var tab: Tab = Self.launchTab
    @State private var filter = ""
    @State private var memberships: [Playlist] = []
    @State private var choices: [PlaylistCard.Model] = []
    @State private var target: Int64?
    @State private var savedTo: String?
    @State private var more: [Item] = []
    @State private var openIdea: Int64?

    private enum Tab: String, Hashable { case breakdown, transcript, save }

    /// Lets a screenshot run open a specific tab. DEBUG-only, so it cannot ship.
    private static var launchTab: Tab {
        #if DEBUG
        if let name = UserDefaults.standard.string(forKey: "quokkaItemTab"), let tab = Tab(rawValue: name) {
            return tab
        }
        #endif
        return .breakdown
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                if let item {
                    VStack(alignment: .leading, spacing: Space.loose) {
                        hero(item)
                        if state.isSampleTranscript(itemID) { sampleBanner }
                        UnderlineTabs(
                            options: [(.breakdown, "Breakdown", nil), (.transcript, "Transcript", nil), (.save, "Save", nil)],
                            selection: $tab)
                        switch tab {
                        case .breakdown: breakdownTab
                        case .transcript: transcriptTab
                        case .save: saveTab(item, width: proxy.size.width)
                        }
                    }
                    .padding(.top, Space.tight)
                    .padding(.bottom, Space.chapter)
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { topControls }
        .background(Surface.canvas)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: Binding(get: { openIdea.map(Opened.init) }, set: { openIdea = $0?.id })) { opened in
            IdeaDetailView(ideaID: opened.id)
        }
        .task(id: itemID) { load() }
        // While the ladder works, look again every couple of seconds; a transcript that lands
        // should appear without anyone pulling to refresh.
        .task(id: queued) {
            while queued, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                load()
            }
        }
    }

    private struct Opened: Identifiable { let id: Int64 }

    // MARK: - Top

    private var topControls: some View {
        HStack {
            CircleButton(icon: "chevron.left", label: "Back") { dismiss() }
            Spacer()
            if let item, let url = URL(string: item.url), url.scheme?.hasPrefix("http") == true {
                Menu {
                    Button { openURL(url) } label: { SwiftUI.Label("Open original", systemImage: "arrow.up.right") }
                    Button {
                        UIPasteboard.general.url = url
                        Haptics.shared.saved()
                    } label: { SwiftUI.Label("Copy link", systemImage: "link") }
                    ShareLink(item: url) { SwiftUI.Label("Share", systemImage: "square.and.arrow.up") }
                } label: {
                    CircleGlyph(icon: "ellipsis")
                }
                .accessibilityLabel("More")
            }
        }
        .padding(.horizontal, Space.gutter)
        .padding(.vertical, Space.tight)
        .background(Surface.canvas)
    }

    // MARK: - Hero

    private func hero(_ item: Item) -> some View {
        Card(padding: Space.base) {
            HStack(alignment: .top, spacing: Space.roomy) {
                ItemTile(item: item, loader: state.loader)
                    .frame(width: 96, height: 128)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))

                VStack(alignment: .leading, spacing: Space.snug) {
                    Text(item.author ?? item.title ?? item.platform.displayName)
                        .font(Type.title(22))
                        .foregroundStyle(Label.primary)
                        .lineLimit(2)
                    Text("\(item.platform.displayName) · saved \(item.savedAt.formatted(.dateTime.month(.abbreviated).day()))")
                        .font(Type.caption)
                        .foregroundStyle(Label.secondary)
                    statusChip
                    Spacer(minLength: 0)
                    if let url = URL(string: item.url), url.scheme?.hasPrefix("http") == true {
                        Button { openURL(url) } label: {
                            OutlinePill(title: "Open original", icon: "arrow.up.right")
                        }
                        .buttonStyle(PressStyle())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, Space.gutter)
    }

    private var statusChip: some View {
        let (text, blue): (String, Bool) = {
            if let breakdown { return ("\(breakdown.passed) of \(breakdown.checks.count) checks", true) }
            if queued { return ("Reading the audio…", true) }
            if failure != nil { return ("No transcript", false) }
            return ("Not transcribed yet", false)
        }()
        return Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(blue ? Sky.accent : Label.secondary)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(blue ? Sky.tint : Surface.field, in: Capsule())
    }

    private var sampleBanner: some View {
        HStack(spacing: Space.snug) {
            Image(systemName: "exclamationmark.circle.fill").font(.system(size: 14))
            Text("Sample transcript — written for screenshots, not from this video.")
                .font(Type.captionEmphasis)
        }
        .foregroundStyle(Label.primary)
        .padding(Space.base)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Surface.raised, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.control, style: .continuous).stroke(Surface.hairlineStrong, lineWidth: Stroke.thin))
        .padding(.horizontal, Space.gutter)
    }

    // MARK: - Breakdown

    @ViewBuilder
    private var breakdownTab: some View {
        if let breakdown {
            VStack(spacing: Space.base) {
                ChecksCard(breakdown: breakdown)
                HookCard(hook: breakdown.hook, onUse: { useHook(breakdown.hook) })
                PacingCard(pacing: breakdown.pacing)
                if !breakdown.beats.isEmpty { BeatsCard(beats: breakdown.beats) }
                EndingCard(ending: breakdown.ending)
            }
            .padding(.horizontal, Space.gutter)
        } else {
            noTranscript
        }
    }

    private var noTranscript: some View {
        Card(padding: Space.loose) {
            VStack(alignment: .leading, spacing: Space.base) {
                QuokkaMark(size: 40, blinks: true)
                Text(queued ? "Reading the audio" : failure == nil ? "No transcript yet" : "Couldn’t get the words")
                    .font(Type.title(22))
                    .foregroundStyle(Label.primary)
                Text(failure ?? (queued
                    ? "Quokka is reading this video on your phone. It takes seconds, not milliseconds — the first one also downloads a speech model."
                    : "A breakdown is read out of what was said. Quokka can listen to this video on your phone and write it out."))
                    .font(Type.body)
                    .foregroundStyle(Label.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if queued {
                    ProgressView().tint(Sky.accent).padding(.top, Space.tight)
                } else if failure == nil {
                    Button {
                        Haptics.shared.tick()
                        state.requestTranscript(itemID)
                        load()
                    } label: {
                        FilledPill(title: "Get the transcript", icon: "waveform")
                    }
                    .buttonStyle(PressStyle())
                    .padding(.top, Space.tight)
                }

                // The route that always works, said where it is needed.
                Text("Fastest and always works: save the video to Photos, then share the file to Quokka.")
                    .font(Type.caption)
                    .foregroundStyle(Label.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, Space.gutter)
    }

    // MARK: - Transcript

    @ViewBuilder
    private var transcriptTab: some View {
        if let transcript, transcript.isUsable {
            VStack(alignment: .leading, spacing: Space.roomy) {
                HStack(spacing: Space.snug) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Label.secondary)
                    TextField("Search the words", text: $filter)
                        .font(Type.field)
                        .autocorrectionDisabled()
                    ShareLink(item: transcript.text) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Label.primary)
                    }
                    .accessibilityLabel("Share the transcript")
                }
                .padding(.horizontal, Space.roomy)
                .frame(height: Control.fieldHeight)
                .background(Surface.raised, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))

                ForEach(Array(lines(transcript).enumerated()), id: \.offset) { _, line in
                    VStack(alignment: .leading, spacing: 3) {
                        if let start = line.start {
                            Text(Self.clock(start))
                                .font(Type.meta(12))
                                .foregroundStyle(Sky.accent)
                        }
                        Text(line.text)
                            .font(Type.body)
                            .foregroundStyle(Label.primary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Text("Read by \(sourceName(transcript.source)).")
                    .font(Type.caption)
                    .foregroundStyle(Label.tertiary)
            }
            .padding(.horizontal, Space.gutter)
        } else {
            noTranscript
        }
    }

    private func lines(_ transcript: Transcript) -> [(start: TimeInterval?, text: String)] {
        let all: [(start: TimeInterval?, text: String)] = transcript.segments.isEmpty
            ? [(nil, transcript.text)]
            : transcript.segments.map { ($0.start, $0.text) }
        let query = filter.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return all }
        return all.filter { $0.text.lowercased().contains(query) }
    }

    private func sourceName(_ source: TranscriptSource) -> String {
        switch source {
        case .sharedFile: "Quokka on this phone, from the file you shared"
        case .resolvedOnDevice: "Quokka on this phone"
        case .hosted: "a hosted service"
        }
    }

    static func clock(_ seconds: TimeInterval) -> String {
        let whole = Int(seconds.rounded(.down))
        return String(format: "%d:%02d", whole / 60, whole % 60)
    }

    // MARK: - Save

    private func saveTab(_ item: Item, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: Space.loose) {
            VStack(alignment: .leading, spacing: Space.base) {
                SectionLabel(text: "Add to a playlist")
                HStack(spacing: Space.snug) {
                    Menu {
                        ForEach(choices) { choice in
                            Button(choice.name) { target = choice.id }
                        }
                        if choices.isEmpty { Text("No playlists yet — make one in Studio") }
                    } label: {
                        HStack(spacing: Space.snug) {
                            Image(systemName: "rectangle.stack").font(.system(size: 14, weight: .semibold))
                            Text(choices.first(where: { $0.id == target })?.name ?? "Choose a playlist")
                                .font(.system(size: 15, weight: .semibold))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.down").font(.system(size: 12, weight: .bold))
                        }
                        .foregroundStyle(Label.primary)
                        .padding(.horizontal, Space.roomy)
                        .frame(height: Control.pillHeight)
                        .background(Surface.raised, in: Capsule())
                    }
                    Button(action: save) {
                        FilledPill(title: savedTo == nil ? "Save" : "Saved", icon: savedTo == nil ? nil : "checkmark", tone: .ink)
                            .frame(width: 104)
                    }
                    .buttonStyle(PressStyle())
                    .disabled(target == nil)
                    .opacity(target == nil ? 0.4 : 1)
                }

                if !memberships.isEmpty {
                    Card(padding: Space.base) {
                        VStack(spacing: 0) {
                            ForEach(memberships) { playlist in
                                if let id = playlist.id {
                                    NavigationLink(value: Route.playlist(id)) {
                                        PlaylistRow(
                                            name: playlist.name,
                                            count: choices.first(where: { $0.id == id })?.count,
                                            cover: state.playlistCover(id, limit: 1),
                                            loader: state.loader)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Space.gutter)

            if !more.isEmpty {
                VStack(alignment: .leading, spacing: Space.base) {
                    SectionLabel(text: "More from \(item.author ?? "this creator")")
                        .padding(.horizontal, Space.gutter)
                    MasonryGrid(
                        items: more,
                        columns: Grid.columns,
                        spacing: Grid.gutter,
                        width: width - Grid.margin * 2
                    ) { other, _ in
                        TileLink(item: other, loader: state.loader)
                    }
                    .padding(.horizontal, Grid.margin)
                }
            }
        }
    }

    // MARK: - Work

    private func load() {
        item = state.item(id: itemID)
        transcript = state.transcript(forItem: itemID)
        breakdown = transcript.flatMap(Breakdown.analyze)
        queued = transcript == nil && state.isTranscriptQueued(itemID)
        failure = transcript == nil ? state.transcriptFailure(itemID) : nil
        memberships = state.playlists(containing: itemID)
        choices = state.playlistCards()
        if target == nil {
            target = choices.first(where: { card in !memberships.contains { $0.id == card.id } })?.id
        }
        if let author = item?.author, let page = state.page(author: author) {
            more = Array(page.items.filter { $0.id != itemID }.prefix(12))
        } else {
            more = []
        }
    }

    private func save() {
        guard let target, let name = choices.first(where: { $0.id == target })?.name else { return }
        state.addToPlaylist(target, itemIDs: [itemID])
        Haptics.shared.saved()
        savedTo = name
        memberships = state.playlists(containing: itemID)
        choices = state.playlistCards()
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            savedTo = nil
        }
    }

    /// Starts an idea from this video's opening line, with the video attached as its source.
    private func useHook(_ hook: Breakdown.Hook) {
        let title = hook.text.count > 60 ? String(hook.text.prefix(59)) + "…" : hook.text
        guard var idea = state.createIdea(title: title, playlistID: nil), let ideaID = idea.id else { return }
        idea.hook = hook.text
        state.save(idea)
        state.addSource(itemID: itemID, toIdea: ideaID)
        Haptics.shared.saved()
        openIdea = ideaID
    }
}

// MARK: - Cards

/// The score and the evidence: how many checks passed, then every check with what decided it.
private struct ChecksCard: View {
    let breakdown: Breakdown

    var body: some View {
        Card(padding: Space.roomy) {
            VStack(alignment: .leading, spacing: Space.roomy) {
                HStack(spacing: Space.roomy) {
                    ZStack {
                        Circle().stroke(Sky.tint, lineWidth: 8)
                        Circle()
                            .trim(from: 0, to: Double(breakdown.passed) / Double(max(breakdown.checks.count, 1)))
                            .stroke(Sky.accent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text("\(breakdown.passed)/\(breakdown.checks.count)")
                            .font(Type.numeral(20))
                            .foregroundStyle(Label.primary)
                    }
                    .frame(width: 72, height: 72)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("What worked")
                            .font(Type.title(22))
                            .foregroundStyle(Label.primary)
                        Text(summary)
                            .font(Type.caption)
                            .foregroundStyle(Label.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VStack(alignment: .leading, spacing: Space.base) {
                    ForEach(breakdown.checks.sorted { $0.passed && !$1.passed }) { check in
                        HStack(alignment: .top, spacing: Space.base) {
                            Image(systemName: check.passed ? "checkmark.circle.fill" : "circle.dashed")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(check.passed ? Sky.accent : Label.dim)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(check.title)
                                    .font(Type.bodyEmphasis)
                                    .foregroundStyle(check.passed ? Label.primary : Label.secondary)
                                Text(check.evidence)
                                    .font(Type.caption)
                                    .foregroundStyle(Label.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(check.passed ? "Passed" : "Missed"): \(check.title). \(check.evidence)")
                    }
                }
            }
        }
    }

    private var summary: String {
        let missed = breakdown.checks.count - breakdown.passed
        switch missed {
        case 0: return "Every check passed. This one is worth studying line by line."
        case 1: return "One thing it skipped — the rest is worth copying."
        default: return "\(breakdown.passed) of \(breakdown.checks.count) checks passed. Keep what worked, fix what didn’t."
        }
    }
}

private struct HookCard: View {
    let hook: Breakdown.Hook
    let onUse: () -> Void

    var body: some View {
        Card(padding: Space.roomy) {
            VStack(alignment: .leading, spacing: Space.base) {
                HStack {
                    SectionLabel(text: "Hook")
                    if let landsAt = hook.landsAt {
                        Text("Lands at \(String(format: "%.1f", landsAt))s")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Sky.accent)
                            .padding(.horizontal, 10)
                            .frame(height: 26)
                            .background(Sky.tint, in: Capsule())
                    }
                }
                Text("“\(hook.text)”")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Label.primary)
                    .fixedSize(horizontal: false, vertical: true)
                if !hook.kinds.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(hook.kinds, id: \.self) { kind in
                            Text(kind.label)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Label.primary)
                                .padding(.horizontal, 10)
                                .frame(height: 28)
                                .background(Surface.field, in: Capsule())
                        }
                    }
                }
                Button(action: onUse) {
                    FilledPill(title: "Use this hook", icon: "sparkles", tone: .ink)
                }
                .buttonStyle(PressStyle())
                .padding(.top, Space.tight)
            }
        }
    }
}

private struct PacingCard: View {
    let pacing: Breakdown.Pacing

    var body: some View {
        Card(padding: Space.roomy) {
            VStack(alignment: .leading, spacing: Space.base) {
                HStack {
                    SectionLabel(text: "Pace")
                    Text(pacing.tempo.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(pacing.tempo == .unknown ? Label.secondary : Sky.accent)
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                        .background(pacing.tempo == .unknown ? Surface.field : Sky.tint, in: Capsule())
                }
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    figure(pacing.wordsPerMinute.map(String.init) ?? "—", "words / min")
                    figure(pacing.duration.map(ItemDetailView.clock) ?? "—", "long")
                    figure("\(pacing.sentences)", pacing.sentences == 1 ? "line" : "lines")
                }
            }
        }
    }

    private func figure(_ value: String, _ unit: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(Type.numeral(28))
                .foregroundStyle(Label.primary)
            Text(unit)
                .font(Type.caption)
                .foregroundStyle(Label.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct BeatsCard: View {
    let beats: [Breakdown.Beat]

    var body: some View {
        Card(padding: Space.roomy) {
            VStack(alignment: .leading, spacing: Space.base) {
                SectionLabel(text: "Structure", trailing: "\(beats.count) beats")
                ForEach(Array(beats.enumerated()), id: \.offset) { index, beat in
                    HStack(alignment: .top, spacing: Space.base) {
                        Text("\(index + 1)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Label.onInverse)
                            .frame(width: 24, height: 24)
                            .background(Surface.inverse, in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(beat.text)
                                .font(Type.body)
                                .foregroundStyle(Label.primary)
                                .fixedSize(horizontal: false, vertical: true)
                            if let start = beat.start {
                                Text(ItemDetailView.clock(start))
                                    .font(Type.meta(12))
                                    .foregroundStyle(Sky.accent)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct EndingCard: View {
    let ending: Breakdown.Ending

    var body: some View {
        Card(padding: Space.roomy) {
            VStack(alignment: .leading, spacing: Space.base) {
                SectionLabel(text: "Ending")
                Text("“\(ending.text)”")
                    .font(Type.body)
                    .foregroundStyle(Label.primary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: Space.snug) {
                    Image(systemName: ending.ask == nil ? "circle.dashed" : "checkmark.circle.fill")
                        .foregroundStyle(ending.ask == nil ? Label.dim : Sky.accent)
                    Text(ending.ask?.label ?? "No ask — the video just stops")
                        .font(Type.captionEmphasis)
                        .foregroundStyle(ending.ask == nil ? Label.secondary : Label.primary)
                }
            }
        }
    }
}

/// A playlist as a row: small cover, name, count.
private struct PlaylistRow: View {
    let name: String
    let count: Int?
    let cover: [Item]
    let loader: ThumbnailLoader?

    var body: some View {
        HStack(spacing: Space.base) {
            Mosaic(items: cover, loader: loader, monogram: Mosaic.monogram(for: name))
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(Type.bodyEmphasis)
                    .foregroundStyle(Label.primary)
                if let count {
                    Text(count == 1 ? "1 save" : "\(count) saves")
                        .font(Type.caption)
                        .foregroundStyle(Label.secondary)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Label.dim)
        }
        .padding(.vertical, Space.snug)
        .contentShape(Rectangle())
    }
}

/// Lays children left to right and wraps. The system has no wrapping stack.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var line: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += line + spacing
                line = 0
            }
            x += size.width + spacing
            line = max(line, size.height)
        }
        return CGSize(width: width == .infinity ? x : width, height: y + line)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var line: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += line + spacing
                line = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            line = max(line, size.height)
        }
    }
}
