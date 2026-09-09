import SwiftUI
import AllimDesign
import AllimEngine

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
                            ItemRow(item: item)
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

    var body: some View {
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
        .padding(.vertical, Space.tight)
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

