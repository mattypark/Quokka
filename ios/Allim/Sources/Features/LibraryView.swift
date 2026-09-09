import SwiftUI
import AllimDesign
import AllimEngine
import AllimImaging

/// The library, at the stage where the storage layer does not exist yet.
///
/// It renders what the share extension actually delivered, including the raw type identifiers
/// each attachment arrived with. That last part is the point: it is how the question of which
/// platforms hand over a thumbnail gets answered, on a device, from the app itself, rather
/// than by reading a console.
struct LibraryView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        NavigationStack {
            Group {
                if let failure = state.storeFailure {
                    StoreFailure(message: failure)
                } else if state.items.isEmpty {
                    EmptyLibrary()
                } else {
                    List {
                        ForEach(state.items) { item in
                            ItemRow(item: item, loader: state.loader)
                                .listRowBackground(Surface.raised)
                                .listRowSeparatorTint(Surface.hairline)
                                .onAppear {
                                    // The last row asking for the next page is the whole
                                    // paging trigger; the keyset cursor makes it safe even
                                    // when saves land at the head mid-scroll.
                                    if item.id == state.items.last?.id { state.loadMore() }
                                }
                        }
                        if !state.lastProbe.isEmpty {
                            ProbeSection(probes: state.lastProbe)
                                .listRowBackground(Surface.canvas)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Surface.canvas)
            .navigationTitle(state.total > 0 ? "\(state.total) saved" : "Allim")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Surface.canvas, for: .navigationBar)
        }
        .tint(Label.primary)
    }
}

private struct EmptyLibrary: View {
    var body: some View {
        VStack(spacing: Space.roomy) {
            Wordmark(size: 34, animated: false, showsNative: false)
                .opacity(0.45)
            Text("Share a post to Allim and it lands here.")
                .font(Type.body)
                .foregroundStyle(Label.secondary)
                .multilineTextAlignment(.center)
            Text("instagram · tiktok · youtube · pinterest · reddit · x")
                .font(Type.meta(11))
                .foregroundStyle(Label.tertiary)
        }
        .padding(Space.section)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ItemRow: View {
    let item: Item
    let loader: ThumbnailLoader?

    var body: some View {
        HStack(alignment: .top, spacing: Space.base) {
            ThumbnailTile(item: item, loader: loader)
            details
        }
        .padding(.vertical, Space.tight)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: Space.snug) {
            HStack(spacing: Space.snug) {
                Text(item.platform.displayName)
                    .font(Type.meta(10))
                    .foregroundStyle(Label.tertiary)
                    .padding(.horizontal, Space.snug)
                    .padding(.vertical, Space.hair)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.pill)
                            .stroke(Surface.border, lineWidth: Stroke.thin)
                    )
                Spacer()
                Text(item.savedAt, format: .dateTime.hour().minute())
                    .font(Type.meta(10))
                    .foregroundStyle(Label.tertiary)
            }

            Text(item.url)
                .font(Type.tileTitle(15))
                .foregroundStyle(Label.primary)
                .lineLimit(3)

            if let author = item.author {
                Text(author)
                    .font(Type.meta(11))
                    .foregroundStyle(Label.secondary)
            }

            Text(item.thumbnailState.rawValue.uppercased())
                .font(Type.meta(9))
                .foregroundStyle(Label.tertiary)
        }
    }
}

/// A tile, in the three states a tile can actually be in.
///
/// The unavailable case is a designed state rather than an error: Instagram, Pinterest and X
/// will never yield an image, so a typographic mark set in the display face IS the artwork for
/// those. Committing to black and white is what makes that read as intent instead of failure.
private struct ThumbnailTile: View {
    let item: Item
    let loader: ThumbnailLoader?

    @State private var image: UIImage?

    private var placeholder: Color {
        // The four bytes stored inline on the row. No decode, no hash -- see AverageColor.
        guard let packed = item.averageColor else { return Surface.elevated }
        let (r, g, b) = AverageColor.components(packed)
        return Color(.sRGB, red: r, green: g, blue: b)
    }

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if item.thumbnailState == .unavailable {
                placeholder.overlay(
                    Text(String(item.platform.displayName.prefix(2)).uppercased())
                        .font(Type.feature(15))
                        .foregroundStyle(Label.tertiary)
                )
            } else {
                placeholder
            }
        }
        .frame(width: 72, height: 96)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(Surface.hairline, lineWidth: Stroke.thin)
        )
        .task(id: item.id) {
            guard let loader, let id = item.id, item.thumbnailState == .stored else { return }
            image = await loader.image(for: id)
        }
    }
}

/// A store that will not open is shown, not swallowed. A library that silently stops
/// persisting is indistinguishable from an empty one.
private struct StoreFailure: View {
    let message: String

    var body: some View {
        VStack(spacing: Space.base) {
            Text("The library could not be opened")
                .font(Type.title(20))
                .foregroundStyle(Label.primary)
            Text(message)
                .font(Type.meta(11))
                .foregroundStyle(Label.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(Space.section)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The stage-0 answer, from the most recent drain. Temporary scaffolding: it exists to record
/// what each app hands the share sheet, and comes out once that question is settled.
private struct ProbeSection: View {
    let probes: [InboxDrain.Drained]

    var body: some View {
        VStack(alignment: .leading, spacing: Space.snug) {
            Text("LAST SHARE PAYLOAD")
                .font(Type.meta(9))
                .foregroundStyle(Label.tertiary)
            ForEach(probes) { probe in
                VStack(alignment: .leading, spacing: 1) {
                    Text(probe.link?.platform.displayName ?? "unknown")
                        .font(Type.meta(10))
                        .foregroundStyle(probe.imageData != nil ? Label.primary : Label.secondary)
                    ForEach(probe.probe, id: \.index) { entry in
                        Text(entry.typeIdentifiers.joined(separator: "  "))
                            .font(Type.meta(9))
                            .foregroundStyle(Label.tertiary)
                    }
                }
            }
        }
        .padding(.vertical, Space.base)
    }
}

