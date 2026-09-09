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
                if state.saves.isEmpty {
                    EmptyLibrary()
                } else {
                    List {
                        ForEach(state.saves) { save in
                            SaveRow(save: save)
                                .listRowBackground(Surface.raised)
                                .listRowSeparatorTint(Surface.hairline)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Surface.canvas)
            .navigationTitle("Allim")
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

private struct SaveRow: View {
    let save: InboxDrain.Drained

    var body: some View {
        VStack(alignment: .leading, spacing: Space.snug) {
            HStack(spacing: Space.snug) {
                Text(save.link?.platform.displayName ?? "Unrecognised")
                    .font(Type.meta(10))
                    .foregroundStyle(Label.tertiary)
                    .padding(.horizontal, Space.snug)
                    .padding(.vertical, Space.hair)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.pill)
                            .stroke(Surface.border, lineWidth: Stroke.thin)
                    )
                Spacer()
                Text(save.receivedAt, format: .dateTime.hour().minute())
                    .font(Type.meta(10))
                    .foregroundStyle(Label.tertiary)
            }

            Text(save.link?.url.absoluteString ?? save.rawText ?? "no link")
                .font(Type.tileTitle(15))
                .foregroundStyle(Label.primary)
                .lineLimit(3)

            if let author = save.link?.author {
                Text(author)
                    .font(Type.meta(11))
                    .foregroundStyle(Label.secondary)
            }

            ProbeReadout(save: save)
        }
        .padding(.vertical, Space.tight)
    }
}

/// The stage-0 answer, rendered. Whether an image came through with the link decides whether
/// Instagram, Pinterest and X can ever show a thumbnail, so it is surfaced rather than logged.
private struct ProbeReadout: View {
    let save: InboxDrain.Drained

    private var carriedImage: Bool {
        save.imageData != nil
            || save.probe.contains { $0.typeIdentifiers.contains { $0.hasPrefix("public.image") } }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.hair) {
            HStack(spacing: Space.tight) {
                Text(carriedImage ? "IMAGE IN PAYLOAD" : "NO IMAGE")
                    .font(Type.meta(9))
                    .foregroundStyle(carriedImage ? Label.primary : Label.tertiary)
                if let bytes = save.imageData?.count {
                    Text("\(bytes / 1024) KB")
                        .font(Type.meta(9))
                        .foregroundStyle(Label.tertiary)
                }
            }
            ForEach(save.probe, id: \.index) { probe in
                Text(probe.typeIdentifiers.joined(separator: "  "))
                    .font(Type.meta(9))
                    .foregroundStyle(Label.tertiary)
                    .lineLimit(2)
            }
        }
        .padding(.top, Space.tight)
    }
}
