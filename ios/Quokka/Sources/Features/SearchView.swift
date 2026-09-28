import SwiftUI
import QuokkaDesign
import QuokkaEngine
import QuokkaImaging

/// Search, the Cosmos way: one warm pill with a colour wheel at its end, playlists as cards
/// underneath, and everything else as a grid.
///
/// Words search titles, creators, captions, tags and transcripts. The wheel searches by
/// colour, which the library can do for free -- every thumbnail's average colour is already
/// stored inline on its row.
struct SearchView: View {
    @Environment(AppState.self) private var state
    @Binding var path: NavigationPath

    @State private var query = ""
    @State private var color: Int?
    @State private var results: [Item] = []
    @State private var swatches: [Int] = []
    @State private var showsColors = false
    @State private var cards: [PlaylistCard.Model] = []
    @State private var picked: Color = .gray
    @FocusState private var focused: Bool

    private var isSearching: Bool {
        color != nil || !query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: Space.base) {
                pill
                    .padding(.horizontal, Space.roomy)
                    .padding(.top, Space.snug)

                if showsColors { swatchRow }

                GeometryReader { proxy in
                    ScrollView(showsIndicators: false) {
                        if isSearching {
                            resultsGrid(width: proxy.size.width)
                        } else {
                            landing(width: proxy.size.width)
                        }
                    }
                    .scrollDismissesKeyboard(.immediately)
                }
            }
            .background(Surface.canvas)
            .toolbar(.hidden, for: .navigationBar)
            .quokkaRoutes()
        }
        .task {
            swatches = state.swatches()
            cards = state.playlistCards()
        }
        .onChange(of: path.count) { _, depth in if depth == 0 { cards = state.playlistCards() } }
        // task(id:) cancels the previous run, which is the debounce: a search starts only once
        // typing has paused for a moment.
        .task(id: query) {
            guard color == nil else { return }
            let trimmed = query.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { results = []; return }
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            results = state.search(text: trimmed)
        }
    }

    // MARK: - Pill

    private var pill: some View {
        HStack(spacing: Space.snug) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Label.secondary)

            if let color {
                Circle()
                    .fill(Self.swiftColor(color))
                    .frame(width: 22, height: 22)
                    .overlay(Circle().stroke(Surface.hairlineStrong, lineWidth: Stroke.thin))
                Text(Self.hex(color))
                    .font(Type.field.monospaced())
                    .foregroundStyle(Label.primary)
                Spacer(minLength: 0)
                Button {
                    self.color = nil
                    results = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(Label.dim)
                }
                .accessibilityLabel("Clear colour")
            } else {
                TextField("Search Quokka", text: $query)
                    .font(Type.field)
                    .tracking(Type.navTracking)
                    .focused($focused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 17))
                            .foregroundStyle(Label.dim)
                    }
                    .accessibilityLabel("Clear search")
                }
            }

            Button {
                Haptics.shared.tick()
                withAnimation(Motion.respecting(.easeOut(duration: 0.2))) { showsColors.toggle() }
                focused = false
            } label: {
                ColorWheel()
                    .frame(width: 22, height: 22)
                    .frame(width: 36, height: 36)
                    .contentShape(Circle())
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel("Search by colour")
        }
        .padding(.leading, Space.roomy)
        .padding(.trailing, Space.snug)
        .frame(height: Control.fieldHeight)
        .background(Surface.field, in: Capsule())
        .overlay(Capsule().stroke(Surface.hairlineStrong, lineWidth: Stroke.thin))
        // Cosmos's inset highlight: a white line just inside the top edge, which is what makes
        // the pill read as a pressed-in field rather than a flat shape.
        .overlay(
            Capsule()
                .inset(by: 1)
                .stroke(
                    LinearGradient(colors: [.white.opacity(0.7), .clear], startPoint: .top, endPoint: .center),
                    lineWidth: 1)
        )
    }

    private var swatchRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.snug) {
                ForEach(swatches, id: \.self) { swatch in
                    Button { search(color: swatch) } label: {
                        Circle()
                            .fill(Self.swiftColor(swatch))
                            .frame(width: 32, height: 32)
                            .overlay(Circle().stroke(Surface.hairline, lineWidth: Stroke.thin))
                            .padding(3)
                            .overlay(Circle().stroke(color == swatch ? Label.primary : .clear, lineWidth: 1.5))
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityLabel("Colour \(Self.hex(swatch))")
                }
                // Any colour, not just the library's -- the system picker, drawn as the wheel.
                ColorPicker("Any colour", selection: $picked, supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 38, height: 38)
            }
            .padding(.horizontal, Space.roomy)
        }
        .onChange(of: picked) { _, value in
            if let packed = Self.packed(value) { search(color: packed) }
        }
        .transition(.opacity)
    }

    // MARK: - Landing

    @ViewBuilder
    private func landing(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: Space.loose) {
            if !cards.isEmpty {
                VStack(alignment: .leading, spacing: Space.base) {
                    sectionTitle("Playlists")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: Space.base) {
                            ForEach(cards) { card in
                                NavigationLink(value: Route.playlist(card.id)) {
                                    PlaylistCard(model: card, items: state.playlistCover(card.id), loader: state.loader)
                                        .frame(width: 150)
                                }
                                .buttonStyle(PressStyle())
                            }
                        }
                        .padding(.horizontal, Space.roomy)
                    }
                }
            }

            if state.items.isEmpty {
                EmptyNote(title: "Nothing to search yet", detail: "Share a post to Quokka from any app.")
            } else {
                VStack(alignment: .leading, spacing: Space.base) {
                    sectionTitle("Recent")
                    MasonryGrid(
                        items: state.items,
                        columns: Grid.columns,
                        spacing: Grid.gutter,
                        width: width - Grid.margin * 2
                    ) { item, _ in
                        TileLink(item: item, loader: state.loader)
                            .onAppear { if item.id == state.items.last?.id { state.loadMore() } }
                    }
                    .padding(.horizontal, Grid.margin)
                }
            }
        }
        .padding(.top, Space.snug)
        .padding(.bottom, Grid.bottomInset)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(Type.nav)
            .tracking(Type.navTracking)
            .foregroundStyle(Label.primary)
            .padding(.horizontal, Space.roomy)
    }

    // MARK: - Results

    @ViewBuilder
    private func resultsGrid(width: CGFloat) -> some View {
        if results.isEmpty {
            EmptyNote(
                title: "Nothing matches",
                detail: color == nil
                    ? "Search looks through titles, creators, captions, tags and transcripts."
                    : "No saved picture is close to that colour.")
        } else {
            VStack(alignment: .leading, spacing: Space.base) {
                Text(results.count == 1 ? "1 result" : "\(results.count) results")
                    .font(Type.caption)
                    .foregroundStyle(Label.secondary)
                    .padding(.horizontal, Space.roomy)
                MasonryGrid(
                    items: results,
                    columns: Grid.columns,
                    spacing: Grid.gutter,
                    width: width - Grid.margin * 2
                ) { item, _ in
                    TileLink(item: item, loader: state.loader)
                }
                .padding(.horizontal, Grid.margin)
            }
            .padding(.top, Space.snug)
            .padding(.bottom, Grid.bottomInset)
        }
    }

    // MARK: - Work

    private func search(color packed: Int) {
        Haptics.shared.tick()
        focused = false
        query = ""
        color = packed
        results = state.search(color: packed)
    }

    static func swiftColor(_ packed: Int) -> Color {
        let (r, g, b) = AverageColor.components(packed)
        return Color(.sRGB, red: r, green: g, blue: b)
    }

    static func hex(_ packed: Int) -> String {
        String(format: "#%06X", packed & 0xFFFFFF)
    }

    static func packed(_ color: Color) -> Int? {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        let clamp = { (value: CGFloat) in Int((min(max(value, 0), 1) * 255).rounded()) }
        return clamp(r) << 16 | clamp(g) << 8 | clamp(b)
    }
}

/// The colour-search glyph: a ring of dots around the hue circle, where Cosmos draws its own.
private struct ColorWheel: View {
    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            ZStack {
                ForEach(0..<8, id: \.self) { index in
                    let angle = Double(index) / 8 * 2 * .pi
                    Circle()
                        .fill(Color(hue: Double(index) / 8, saturation: 0.75, brightness: 0.95))
                        .frame(width: size * 0.26, height: size * 0.26)
                        .offset(x: cos(angle) * size * 0.36, y: sin(angle) * size * 0.36)
                }
            }
            .frame(width: size, height: size)
        }
        .accessibilityHidden(true)
    }
}
