import SwiftUI
import QuokkaDesign
import QuokkaEngine

/// The playlists a person made, as Cosmos clusters: a square cover, the name, the count.
///
/// A pane inside the profile rather than a screen of its own, so it draws no scroll view and
/// no header -- the profile owns both.
struct PlaylistsPane: View {
    @Environment(AppState.self) private var state
    @Binding var path: NavigationPath

    @State private var cards: [PlaylistCard.Model] = []
    @State private var creating = false
    @State private var draftName = ""

    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: Grid.gutter), GridItem(.flexible(), spacing: Grid.gutter)]
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: Space.loose) {
            Button { draftName = ""; creating = true } label: {
                NewPlaylistCard()
            }
            .buttonStyle(PressStyle())

            ForEach(cards) { card in
                NavigationLink(value: Route.playlist(card.id)) {
                    PlaylistCard(
                        model: card,
                        items: state.playlistCover(card.id),
                        loader: state.loader)
                }
                .buttonStyle(PressStyle())
            }
        }
        .padding(.horizontal, Grid.margin)
        .alert("New playlist", isPresented: $creating) {
            TextField("Name", text: $draftName)
            Button("Create") { create() }
            Button("Cancel", role: .cancel) {}
        }
        .task {
            reload()
            openForScreenshot()
        }
        // Returning from a playlist that was renamed, filled or deleted.
        .onChange(of: path.count) { _, depth in if depth == 0 { reload() } }
    }

    private func reload() { cards = state.playlistCards() }

    /// Pushes into a playlist, for screenshot runs. DEBUG-only so it cannot ship.
    ///
    /// The fullest playlist, not the first: a screenshot of an empty one proves nothing.
    private func openForScreenshot() {
        #if DEBUG
        guard let screen = UserDefaults.standard.string(forKey: "quokkaScreen"),
              screen == "playlist" || screen == "idea",
              path.isEmpty,
              let target = cards.max(by: { $0.count < $1.count })
        else { return }
        path.append(Route.playlist(target.id))
        #endif
    }

    private func create() {
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let made = state.createPlaylist(name: trimmed), let id = made.id {
            reload()
            path.append(Route.playlist(id))
        }
    }
}

struct PlaylistCard: View {
    struct Model: Identifiable, Hashable {
        let id: Int64
        let name: String
        let count: Int
    }

    let model: Model
    let items: [Item]
    let loader: ThumbnailLoader?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.snug) {
            Mosaic(items: items, loader: loader, monogram: Mosaic.monogram(for: model.name))
                .aspectRatio(1, contentMode: .fit)
                .tileShape(.cover)

            VStack(alignment: .leading, spacing: 1) {
                Text(model.name)
                    .font(Type.bodyEmphasis)
                    .foregroundStyle(Label.primary)
                    .lineLimit(1)
                Text(model.count == 1 ? "1 save" : "\(model.count) saves")
                    .font(Type.caption)
                    .foregroundStyle(Label.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(model.name), \(model.count) saved")
    }
}

/// The first card in the grid is the way to make another -- where Cosmos puts "New cluster".
private struct NewPlaylistCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Space.snug) {
            ZStack {
                Surface.field
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(Label.secondary)
            }
            .aspectRatio(1, contentMode: .fit)
            .tileShape(.cover, stroked: true)

            VStack(alignment: .leading, spacing: 1) {
                Text("New playlist")
                    .font(Type.bodyEmphasis)
                    .foregroundStyle(Label.primary)
                Text(" ")
                    .font(Type.caption)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("New playlist")
    }
}
