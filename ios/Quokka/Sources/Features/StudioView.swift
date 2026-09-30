import SwiftUI
import QuokkaDesign
import QuokkaEngine

/// Studio: where saved videos turn into your own.
///
/// For you -- what your own saves say about your taste -- first, then Playlists to group what
/// you saved, Ideas for the scripts and the planner, and Creators, the library grouped by who
/// made it. The tab row pins as the content scrolls.
struct StudioView: View {
    @Environment(AppState.self) private var state
    @Binding var path: NavigationPath
    var scrollToTop = 0

    @State private var pane: Pane = Self.launchPane
    @State private var creating = false
    @State private var draftName = ""

    enum Pane: Hashable { case forYou, playlists, ideas, creators }

    /// Screenshot runs deep-linking into a playlist or an idea start on that pane. DEBUG-only.
    private static var launchPane: Pane {
        #if DEBUG
        if UserDefaults.standard.string(forKey: "quokkaPane") == "ideas" { return .ideas }
        if UserDefaults.standard.string(forKey: "quokkaPane") == "creators" { return .creators }
        if UserDefaults.standard.string(forKey: "quokkaPane") == "playlists" { return .playlists }
        if UserDefaults.standard.string(forKey: "quokkaScreen") == "playlist" { return .playlists }
        #endif
        return .forYou
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollViewReader { reader in
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        ScreenTitle(title: "Studio", subtitle: "Turn what you saved into your own") {
                            if pane == .playlists {
                                CircleButton(icon: "plus", label: "New playlist") {
                                    draftName = ""
                                    creating = true
                                }
                            }
                        }
                        .id(Self.top)
                        .padding(.bottom, Space.roomy)

                        Section {
                            contents.padding(.top, Space.roomy)
                        } header: {
                            // No counts on this row: four titles and a badge do not fit a
                            // small phone, and each pane says its own count.
                            UnderlineTabs(
                                options: [
                                    (.forYou, "For you", nil),
                                    (.playlists, "Playlists", nil),
                                    (.ideas, "Ideas", nil),
                                    (.creators, "Creators", nil),
                                ],
                                selection: $pane)
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
            .background(Surface.canvas)
            .toolbar(.hidden, for: .navigationBar)
            .quokkaRoutes()
        }
        .alert("New playlist", isPresented: $creating) {
            TextField("Name", text: $draftName)
            Button("Create") { create() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private static let top = "top"

    @ViewBuilder
    private var contents: some View {
        switch pane {
        case .forYou: ForYouPane()
        case .playlists: PlaylistsPane(path: $path)
        case .ideas: IdeasPane()
        case .creators: CreatorsPane()
        }
    }

    private func create() {
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let made = state.createPlaylist(name: trimmed), let id = made.id {
            path.append(Route.playlist(id))
        }
    }
}
