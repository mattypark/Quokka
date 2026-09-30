import SwiftUI
import QuokkaDesign
import QuokkaEngine
import QuokkaImaging

/// Library: everything saved, as a grid, with search and a filter by platform.
///
/// Search takes words -- titles, creators, captions, tags and transcripts -- or a colour from
/// the wheel at the end of the field, which the library can answer for free because every
/// thumbnail's average colour is already stored on its row.
struct LibraryView: View {
    @Environment(AppState.self) private var state
    @Binding var path: NavigationPath
    var scrollToTop = 0

    @State private var query = ""
    @State private var color: Int?
    @State private var results: [Item] = []
    @State private var swatches: [Int] = []
    @State private var showsColors = false
    @State private var platform: Platform?
    @State private var picked: Color = .gray
    @FocusState private var focused: Bool

    private var isSearching: Bool {
        color != nil || !query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// The platforms actually in the library, most common first -- a chip for a platform
    /// with nothing saved from it is a filter that can only return nothing.
    private var platforms: [Platform] {
        let counts = Dictionary(grouping: state.items, by: \.platform).mapValues(\.count)
        return counts.sorted { $0.value > $1.value }.map(\.key)
    }

    private var visible: [Item] {
        let base = isSearching ? results : state.items
        guard let platform else { return base }
        return base.filter { $0.platform == platform }
    }

    var body: some View {
        NavigationStack(path: $path) {
            GeometryReader { proxy in
                ScrollViewReader { reader in
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: Space.roomy) {
                            ScreenTitle(title: "Library", subtitle: subtitle)
                                .id(Self.top)
                            searchField.padding(.horizontal, Space.gutter)
                            if showsColors { swatchRow }
                            chips
                            grid(width: proxy.size.width)
                        }
                        .padding(.bottom, Grid.bottomInset)
                    }
                    .scrollDismissesKeyboard(.immediately)
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
        .task { swatches = state.swatches() }
        // task(id:) cancels the previous run, which is the debounce: a search starts once
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

    private static let top = "top"

    private var subtitle: String {
        if isSearching { return results.count == 1 ? "1 result" : "\(results.count) results" }
        return state.total == 1 ? "1 saved" : "\(state.total) saved"
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: Space.snug) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
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
                    Image(systemName: "xmark.circle.fill").font(.system(size: 17)).foregroundStyle(Label.dim)
                }
                .accessibilityLabel("Clear colour")
            } else {
                TextField("Search words, creators, colours", text: $query)
                    .font(Type.field)
                    .focused($focused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 17)).foregroundStyle(Label.dim)
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
                    .frame(width: 34, height: 34)
                    .contentShape(Circle())
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel("Search by colour")
        }
        .padding(.leading, Space.roomy)
        .padding(.trailing, Space.snug)
        .frame(height: Control.fieldHeight)
        .background(Surface.raised, in: Capsule())
        .overlay(Capsule().stroke(Surface.hairline, lineWidth: Stroke.thin))
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
                ColorPicker("Any colour", selection: $picked, supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 38, height: 38)
            }
            .padding(.horizontal, Space.gutter)
        }
        .onChange(of: picked) { _, value in
            if let packed = Self.packed(value) { search(color: packed) }
        }
        .transition(.opacity)
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.snug) {
                Chip(title: "All", selected: platform == nil) { platform = nil }
                ForEach(platforms, id: \.self) { option in
                    Chip(title: option.displayName, selected: platform == option) {
                        platform = platform == option ? nil : option
                    }
                }
            }
            .padding(.horizontal, Space.gutter)
        }
    }

    // MARK: - Grid

    @ViewBuilder
    private func grid(width: CGFloat) -> some View {
        if state.items.isEmpty {
            EmptyNote(title: "Nothing saved yet", detail: "Share a video to Quokka from any app.")
        } else if visible.isEmpty {
            EmptyNote(
                title: "Nothing matches",
                detail: color == nil
                    ? "Search looks through titles, creators, captions, tags and transcripts."
                    : "No saved picture is close to that colour.")
        } else {
            MasonryGrid(
                items: visible,
                columns: Grid.columns,
                spacing: Grid.gutter,
                width: width - Grid.margin * 2
            ) { item, _ in
                TileLink(item: item, loader: state.loader)
                    .onAppear {
                        // The keyset cursor makes this safe even when saves land at the head
                        // mid-scroll, which OFFSET paging would not be.
                        if !isSearching, item.id == state.items.last?.id { state.loadMore() }
                    }
            }
            .padding(.horizontal, Grid.margin)
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

/// The colour-search glyph: a ring of hue dots.
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
