import SwiftUI
import PhotosUI
import QuokkaDesign
import QuokkaEngine

/// The person's own page -- Cosmos's profile, one for one.
///
/// Picture, name and counts at the top; a black pill and two outlined circles under that;
/// then tabs that split the width with an underline under the active one. The tabs pin to the
/// top as the grid scrolls, so switching never means scrolling back up first.
///
/// Where Cosmos has Elements and Clusters, this has Saves, Playlists and Ideas -- the planner
/// and the script editor live here now, since the main navigation is only Home, Search and
/// this.
struct ProfileView: View {
    @Environment(AppState.self) private var state
    @Environment(ProfileIdentity.self) private var profile
    @Binding var path: NavigationPath
    var scrollToTop = 0
    var onImport: () -> Void = {}

    @State private var pane: Pane = Self.launchPane
    @State private var playlistCount = 0
    @State private var showingSettings = false
    @State private var naming = false
    @State private var draftName = ""
    @State private var photo: PhotosPickerItem?

    enum Pane: Hashable { case saves, playlists, ideas }

    /// Screenshot runs deep-linking into a playlist start on that tab. DEBUG-only.
    private static var launchPane: Pane {
        #if DEBUG
        let screen = UserDefaults.standard.string(forKey: "quokkaScreen")
        if screen == "playlist" || screen == "idea" { return .playlists }
        if UserDefaults.standard.string(forKey: "quokkaPane") == "ideas" { return .ideas }
        #endif
        return .saves
    }

    var body: some View {
        NavigationStack(path: $path) {
            GeometryReader { proxy in
                ScrollViewReader { reader in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                            header
                                .id(Self.top)
                                .padding(.bottom, Space.roomy)

                            Section {
                                paneContents(width: proxy.size.width)
                                    .padding(.top, Space.base)
                            } header: {
                                UnderlineTabs(
                                    options: [
                                        (.saves, "Saves", state.total),
                                        (.playlists, "Playlists", playlistCount),
                                        (.ideas, "Ideas", nil),
                                    ],
                                    selection: $pane
                                )
                                .background(Surface.canvas)
                            }
                        }
                        .padding(.bottom, Grid.bottomInset)
                    }
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
        .sheet(isPresented: $showingSettings) { SettingsView() }
        .alert("Your name", isPresented: $naming) {
            TextField("Name", text: $draftName)
            Button("Save") { profile.name = draftName.trimmingCharacters(in: .whitespacesAndNewlines) }
            Button("Cancel", role: .cancel) {}
        }
        .onChange(of: photo) { _, picked in
            guard let picked else { return }
            Task {
                if let data = try? await picked.loadTransferable(type: Data.self) {
                    profile.setAvatar(data)
                }
                photo = nil
            }
        }
        .task { playlistCount = state.playlistCards().count }
        .onChange(of: path.count) { _, depth in
            if depth == 0 { playlistCount = state.playlistCards().count }
        }
    }

    private static let top = "top"

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.roomy) {
            HStack(spacing: Space.base) {
                PhotosPicker(selection: $photo, matching: .images) {
                    Avatar(image: profile.avatar, name: profile.name, size: 64)
                }
                .accessibilityLabel("Change picture")

                VStack(alignment: .leading, spacing: 2) {
                    Button {
                        draftName = profile.name
                        naming = true
                    } label: {
                        Text(profile.displayName)
                            .font(Type.name)
                            .tracking(-0.3)
                            .foregroundStyle(Label.primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Edit your name")

                    Text(summary)
                        .font(Type.nav)
                        .foregroundStyle(Label.secondary)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: Space.snug) {
                Button(action: onImport) {
                    FilledPill(title: "Import", icon: "arrow.down")
                }
                .buttonStyle(PressStyle())
                .accessibilityLabel("Import from Instagram")

                Button { draftName = profile.name; naming = true } label: {
                    OutlineCircle(icon: "pencil")
                }
                .buttonStyle(PressStyle())
                .accessibilityLabel("Edit name")

                Button { showingSettings = true } label: {
                    OutlineCircle(icon: "gearshape")
                }
                .buttonStyle(PressStyle())
                .accessibilityLabel("Settings")
            }
        }
        .padding(.horizontal, Space.roomy)
        .padding(.top, Space.loose)
    }

    private var summary: String {
        let saves = state.total == 1 ? "1 save" : "\(state.total) saves"
        let playlists = playlistCount == 1 ? "1 playlist" : "\(playlistCount) playlists"
        return "\(saves) · \(playlists)"
    }

    // MARK: - Panes

    @ViewBuilder
    private func paneContents(width: CGFloat) -> some View {
        switch pane {
        case .saves:
            if state.items.isEmpty {
                EmptyNote(title: "Nothing saved yet", detail: "Share a post to Quokka from any app.")
            } else {
                MasonryGrid(
                    items: state.items,
                    columns: Grid.columnsWide,
                    spacing: Space.snug,
                    width: width - Grid.margin * 2
                ) { item, _ in
                    TileLink(item: item, loader: state.loader)
                        .onAppear { if item.id == state.items.last?.id { state.loadMore() } }
                }
                .padding(.horizontal, Grid.margin)
            }
        case .playlists:
            PlaylistsPane(path: $path)
        case .ideas:
            IdeasPane()
        }
    }
}
