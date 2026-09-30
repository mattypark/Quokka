import SwiftUI
import QuokkaDesign
import QuokkaEngine
import QuokkaImaging

/// Home: the whole page is sky, and it is full of pictures.
///
/// No dashboard and no counts in rings. A hand-written hello and the sun crossing the top with
/// the hour; the two ways in; the videos ready to break down as white cards you swipe through;
/// then a wall of everything saved that has a picture, Pinterest-dense, straight on the blue.
/// Text-only saves live in the Library -- the wall is for looking.
struct HomeView: View {
    @Environment(AppState.self) private var state
    @Environment(\.skyPassage) private var passage
    @Binding var path: NavigationPath
    var scrollToTop = 0
    var onImport: () -> Void = {}
    var onSettings: () -> Void = {}
    var onLibrary: () -> Void = {}

    @State private var ready: [Item] = []
    @State private var waiting: [Item] = []
    @State private var addingLink = false

    /// Only saves with a picture. The wall is for looking; a text card on it is a hole.
    private var pictures: [Item] {
        state.items.filter { $0.thumbnailState == .stored }
    }

    var body: some View {
        NavigationStack(path: $path) {
            GeometryReader { proxy in
                ScrollViewReader { reader in
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: Space.section - Space.snug) {
                            hello.id(Self.top)
                            if !ready.isEmpty { readySection }
                            if !waiting.isEmpty { waitingSection }
                            wall(width: proxy.size.width).id(Self.wallAnchor)
                        }
                        .padding(.bottom, Grid.bottomInset)
                    }
                    .task {
                        #if DEBUG
                        // Screenshot runs can land on the wall: -quokkaScrollTo wall.
                        guard UserDefaults.standard.string(forKey: "quokkaScrollTo") == "wall" else { return }
                        try? await Task.sleep(for: .seconds(1))
                        reader.scrollTo(Self.wallAnchor, anchor: .top)
                        #endif
                    }
                    .onChange(of: scrollToTop) {
                        withAnimation(Motion.respecting(.easeOut(duration: 0.3))) {
                            reader.scrollTo(Self.top, anchor: .top)
                        }
                    }
                }
            }
            .background(SkyBackground(showsSun: true).ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .quokkaRoutes()
        }
        .sheet(isPresented: $addingLink) { AddLinkSheet(onImport: onImport) }
        .task { refresh() }
        .onChange(of: state.total) { refresh() }
        .onChange(of: path.count) { _, depth in if depth == 0 { refresh() } }
        .task { await openForScreenshot() }
    }

    private static let top = "top"
    private static let wallAnchor = "wall"

    // MARK: - Hello

    private var hello: some View {
        VStack(alignment: .leading, spacing: Space.loose) {
            HStack {
                QuokkaMark(size: 34, blinks: true)
                    .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
                Spacer()
                CircleButton(icon: "gearshape.fill", label: "Settings", onSky: true, action: onSettings)
            }

            VStack(alignment: .leading, spacing: Space.snug) {
                Text(Self.greeting())
                    .font(Type.hand(44))
                    .foregroundStyle(Label.onSky)
                Text(summary)
                    .font(Type.body)
                    .foregroundStyle(Label.onSkySecondary)
            }
            .padding(.top, Space.chapter)

            HStack(spacing: Space.base) {
                Button { addingLink = true } label: {
                    GlassPill(title: "Add a link", icon: "link")
                }
                .buttonStyle(PressStyle())
                Button(action: onImport) {
                    GlassPill(title: "Import", icon: "square.and.arrow.down")
                }
                .buttonStyle(PressStyle())
            }
        }
        .padding(.horizontal, Space.gutter)
        .padding(.top, Space.snug)
    }

    /// What the day is called where you are. A greeting that ignores the clock reads as a
    /// template; one that knows it is evening reads as someone there.
    static func greeting(at date: Date = .now, calendar: Calendar = .current) -> String {
        switch calendar.component(.hour, from: date) {
        case 5..<12: "Good morning"
        case 12..<17: "Good afternoon"
        case 17..<22: "Good evening"
        default: "Up late?"
        }
    }

    private var summary: String {
        if state.total == 0 { return "Save a video and see what made it work." }
        let saves = state.total == 1 ? "1 save" : "\(state.total) saves"
        guard !ready.isEmpty else { return "\(saves). Transcribe one to break it down." }
        return "\(saves), \(ready.count) ready to break down."
    }

    // MARK: - Ready

    /// The videos with words in, as white cards you swipe through -- picture, hook, check dots.
    private var readySection: some View {
        VStack(alignment: .leading, spacing: Space.base) {
            SectionLabel(text: "Ready to break down", trailing: "\(ready.count)", onSky: true)
                .padding(.horizontal, Space.gutter)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: Space.base) {
                    ForEach(ready) { item in
                        if let id = item.id {
                            Button { open(.item(id)) } label: {
                                ReadyCard(item: item, breakdown: state.breakdown(forItem: id), loader: state.loader)
                            }
                            .buttonStyle(PressStyle())
                        }
                    }
                }
                .padding(.horizontal, Space.gutter)
                .padding(.bottom, Space.base)
            }
        }
    }

    // MARK: - Waiting

    private var waitingSection: some View {
        VStack(alignment: .leading, spacing: Space.base) {
            SectionLabel(text: "Needs a transcript", trailing: "\(waiting.count)", onSky: true)
            VStack(spacing: 0) {
                ForEach(Array(waiting.prefix(4).enumerated()), id: \.element.id) { index, item in
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
                            onOpen: { open(.item(id)) })
                        if index < min(waiting.count, 4) - 1 {
                            Rectangle().fill(Sky.glassStroke).frame(height: Stroke.thin)
                                .padding(.leading, 72)
                        }
                    }
                }
            }
            .background(Sky.glass, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).stroke(Sky.glassStroke, lineWidth: Stroke.thin))
        }
        .padding(.horizontal, Space.gutter)
    }

    // MARK: - Wall

    private func wall(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: Space.base) {
            HStack {
                SectionLabel(text: "Your wall", onSky: true)
                Button("Library", action: onLibrary)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Label.onSky)
            }
            .padding(.horizontal, Space.gutter)

            if pictures.count < 6 { fillTheWall.padding(.horizontal, Space.gutter) }

            if !pictures.isEmpty {
                MasonryGrid(
                    items: pictures,
                    columns: Grid.columns,
                    spacing: Grid.gutter,
                    width: width - Grid.margin * 2
                ) { item, _ in
                    TileLink(item: item, loader: state.loader)
                        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
                        .onAppear { if item.id == pictures.last?.id { state.loadMore() } }
                }
                .padding(.horizontal, Grid.margin)
            }
        }
    }

    /// A short wall asks to be filled, and says how -- one pasted board is twenty-five pictures.
    private var fillTheWall: some View {
        Button { addingLink = true } label: {
            HStack(spacing: Space.base) {
                Image(systemName: "photo.stack.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Label.onSky)
                    .frame(width: 44, height: 44)
                    .background(Sky.glass, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Fill your wall")
                        .font(Type.hand(22))
                        .foregroundStyle(Label.onSky)
                    Text("Paste a Pinterest board or an Are.na channel and bring in every picture on it.")
                        .font(Type.caption)
                        .foregroundStyle(Label.onSkySecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(Space.roomy)
            .background(Sky.glass, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).stroke(Sky.glassStroke, lineWidth: Stroke.thin))
        }
        .buttonStyle(PressStyle())
    }

    // MARK: - Work

    /// Opens through the sky passage, so the sky drains into the page; a plain push if Home is
    /// ever shown without one.
    private func open(_ route: Route) {
        if let passage {
            passage.open(route)
        } else {
            path.append(route)
        }
    }

    private func refresh() {
        ready = state.transcribedItems(limit: 8)
        waiting = state.untranscribedVideos(limit: 20)
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

/// A video ready to break down: its picture, the hook as said, and the check dots.
private struct ReadyCard: View {
    let item: Item
    let breakdown: Breakdown?
    let loader: ThumbnailLoader?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.snug) {
            ItemTile(item: item, loader: loader)
                .frame(width: 220, height: 132)
                .clipShape(RoundedRectangle(cornerRadius: Radius.cover, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(item.author ?? item.title ?? item.platform.displayName)
                    .font(Type.captionEmphasis)
                    .foregroundStyle(Label.secondary)
                    .lineLimit(1)
                if let breakdown {
                    Text("“\(breakdown.hook.text)”")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Label.primary)
                        .lineLimit(2, reservesSpace: true)
                        .multilineTextAlignment(.leading)
                    CheckDots(checks: breakdown.checks)
                }
            }
            .padding(.horizontal, Space.tight)
            .padding(.bottom, Space.tight)
        }
        .padding(Space.snug)
        .frame(width: 236)
        .background(Surface.raised, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
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

/// A video with no words yet, in glass on the sky, and the one thing to do about it.
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
                        .frame(width: 44, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.author ?? item.title ?? item.platform.displayName)
                            .font(Type.bodyEmphasis)
                            .foregroundStyle(Label.onSky)
                            .lineLimit(1)
                        Text(status)
                            .font(Type.caption)
                            .foregroundStyle(Label.onSkySecondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if queued {
                ProgressView().controlSize(.small).tint(.white)
            } else if failure == nil {
                Button(action: onRequest) {
                    Text("Transcribe")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Sky.accent)
                        .padding(.horizontal, Space.base)
                        .frame(height: 32)
                        .background(Ink.white, in: Capsule())
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
