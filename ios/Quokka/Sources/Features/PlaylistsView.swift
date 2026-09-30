import SwiftUI
import QuokkaDesign
import QuokkaEngine

/// The playlists a person made: a square cover, the name, the count.
///
/// A pane inside Studio rather than a screen of its own, so it draws no scroll view and no
/// header -- Studio owns both, and its + makes a new one.
struct PlaylistsPane: View {
    @Environment(AppState.self) private var state
    @Binding var path: NavigationPath

    @State private var cards: [PlaylistCard.Model] = []

    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: Grid.gutter), GridItem(.flexible(), spacing: Grid.gutter)]
    }

    @ViewBuilder
    private var content: some View {
        if cards.isEmpty {
            EmptyNote(
                title: "No playlists yet",
                detail: "Tap + to start one, then drop saved videos into it from their breakdown.")
        } else {
            grid
        }
    }

    private var grid: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: Space.loose) {
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
        .padding(.horizontal, Space.gutter)
    }

    var body: some View {
        content
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
