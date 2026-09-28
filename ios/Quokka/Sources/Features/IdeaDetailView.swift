import SwiftUI
import QuokkaDesign
import QuokkaEngine
import QuokkaImaging

/// The screen the product is actually for.
///
/// Everything else in Quokka exists to get a person here: a script they can copy, with the
/// videos that inspired it kept beside it. Saving is table stakes.
struct IdeaDetailView: View {
    let ideaID: Int64

    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss

    @State private var idea: Idea?
    @State private var sources: [Item] = []
    @State private var pane: Pane = .note
    @State private var copied = false

    /// Where the words come from until the store can hand one over. See TranscriptAccess.swift.
    var transcripts: TranscriptReading = UnbuiltTranscripts()

    private enum Pane: Hashable { case note, transcript, inspiration }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomLeading) {
                Surface.canvas.ignoresSafeArea()

                VStack(spacing: 0) {
                    UnderlineTabs(
                        options: [(.note, "Note", nil), (.transcript, "Transcript", nil), (.inspiration, "Inspiration", nil)],
                        selection: $pane
                    )
                    .padding(.bottom, Space.base)

                    switch pane {
                    case .note: note
                    case .transcript: transcript
                    case .inspiration: inspiration
                    }
                }

                // The video sits ON the script, bottom-left, rather than above or beside it.
                // That single overlap is what makes the screen read as derived from a video
                // instead of as a document that happens to have one attached.
                if pane != .inspiration, let first = sources.first {
                    SourceChip(item: first, loader: state.loader)
                        .padding(.leading, Space.roomy)
                        .padding(.bottom, Space.loose)
                        .transition(.opacity)
                }
            }
            .navigationTitle(idea.map { "Preview: \($0.title)" } ?? "Idea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Surface.canvas, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { save(); dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Close")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: idea?.body ?? "") { Image(systemName: "square.and.arrow.up") }
                        .disabled(idea?.hasScript != true)
                }
            }
        }
        .tint(Label.primary)
        .task { load() }
    }

    // MARK: - Note

    private var note: some View {
        FadingScroll {
            VStack(alignment: .leading, spacing: Space.base) {
                HStack(alignment: .top, spacing: Space.base) {
                    Text(idea?.title ?? "")
                        .font(Type.title(26))
                        .foregroundStyle(Label.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)

                    // Copy sits with the title, not inside a share sheet. Copying the script
                    // is the point of the screen, so it is one tap and always visible.
                    if idea?.hasScript == true {
                        Button(action: copy) {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Label.primary)
                                .frame(width: Control.circle, height: Control.circle)
                                .background(Surface.control, in: Circle())
                        }
                        .accessibilityLabel(copied ? "Copied" : "Copy script")
                    }
                }

                if idea?.isSample == true {
                    // Said plainly, on the screen, next to the text it describes. Invented
                    // words presented as a real transcript would be the product lying; an
                    // obvious placeholder is scaffolding.
                    HStack(spacing: Space.snug) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.system(size: 12))
                        Text("Sample text — not a transcript of this video")
                            .font(Type.caption)
                    }
                    .foregroundStyle(Label.primary)
                    .padding(.horizontal, Space.base)
                    .padding(.vertical, Space.snug)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Surface.field)
                    .tileShape(.control, stroked: true)
                }

                if let hook = idea?.hook, !hook.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Hook")
                            .font(Type.caption)
                            .foregroundStyle(Label.secondary)
                        Text(hook)
                            .font(Type.bodyEmphasis)
                            .foregroundStyle(Label.primary)
                    }
                    .padding(Space.base)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Surface.field)
                    .tileShape(.control, stroked: true)
                }

                ScriptEditor(text: Binding(
                    get: { idea?.body ?? "" },
                    set: { idea?.body = $0 }
                ))
            }
            .padding(.horizontal, Space.roomy)
            // Clears the floating video and the toolbar, so the last line of script is never
            // stuck underneath either of them.
            .padding(.bottom, 200)
        }
    }

    // MARK: - Transcript

    /// The words that were actually said, as opposed to the note written about them.
    ///
    /// Four states, and they are genuinely different things. No transcript yet is not a
    /// failure; a failure that will be retried is not worth showing; and a failure that has
    /// run out of rungs is the one that matters, because it is the only one with something for
    /// the person to do about it.
    private var transcript: some View {
        Group {
            if let item = sources.first, let id = item.id {
                if let result = transcripts.transcript(forItem: id) {
                    FadingScroll {
                        VStack(alignment: .leading, spacing: Space.base) {
                            // Where it came from, said quietly. `hosted` is the only value
                            // that means anything left this device, which is worth being able
                            // to check rather than take on trust.
                            Text(result.source.rawValue)
                                .font(Type.caption)
                                .foregroundStyle(Label.secondary)

                            Text(result.text)
                                .font(Type.body)
                                .foregroundStyle(Label.primary)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Space.roomy)
                        .padding(.bottom, 200)
                    }
                } else if transcripts.isTranscribing(itemID: id) {
                    message(
                        "Reading the audio",
                        "It is seconds, not milliseconds — and the first one also downloads a speech model."
                    )
                } else if let reason = transcripts.transcriptFailure(forItem: id) {
                    // The sentence the ladder wrote, verbatim. It is an instruction rather than
                    // an error code precisely so it can be shown to a person unedited.
                    message("No audio to read", reason)
                } else {
                    VStack(spacing: Space.base) {
                        message(
                            "Not transcribed yet",
                            "Quokka can read the audio of this video on your device and write out what was said."
                        )
                        Button { transcripts.requestTranscript(itemID: id) } label: {
                            FilledPill(title: "Get the transcript")
                                .frame(width: 220)
                        }
                        .buttonStyle(PressStyle())
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                message("No video attached", "A transcript comes from a video. Attach one first.")
            }
        }
    }

    private func message(_ title: String, _ detail: String) -> some View {
        VStack(spacing: Space.snug) {
            Text(title).font(Type.bodyEmphasis).foregroundStyle(Label.primary)
            Text(detail)
                .font(Type.caption)
                .foregroundStyle(Label.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Space.section)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Inspiration

    private var inspiration: some View {
        Group {
            if sources.isEmpty {
                VStack(spacing: Space.snug) {
                    Text("Nothing attached yet")
                        .font(Type.body)
                        .foregroundStyle(Label.secondary)
                    Text("Add the videos this idea came from.")
                        .font(Type.caption)
                        .foregroundStyle(Label.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: Grid.gutter),
                                  GridItem(.flexible(), spacing: Grid.gutter)],
                        spacing: Grid.gutter
                    ) {
                        ForEach(sources) { item in
                            ItemTile(item: item, loader: state.loader)
                                .frame(height: 210)
                        }
                    }
                    .padding(.horizontal, Grid.margin)
                    .padding(.bottom, 120)
                }
            }
        }
    }

    // MARK: - Work

    private func load() {
        idea = state.idea(id: ideaID)
        sources = state.sources(forIdea: ideaID)
    }

    private func save() {
        guard let idea else { return }
        state.save(idea)
    }

    private func copy() {
        guard let body = idea?.body, !body.isEmpty else { return }
        UIPasteboard.general.string = body
        Haptics.shared.saved()
        withAnimation(Motion.respecting(.easeOut(duration: 0.15))) { copied = true }
        // Reverts rather than staying ticked, so the control reads as an action that happened
        // rather than as a state the screen is now in.
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(Motion.respecting(.easeOut(duration: 0.2))) { copied = false }
        }
    }
}

/// The script itself.
///
/// Editable from the moment the idea exists. Whether the words arrived from a transcript or
/// were typed by hand, it is the same field on the same screen -- which is the degradation
/// decision made once, in the right place, rather than as two code paths.
private struct ScriptEditor: View {
    @Binding var text: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text("Write the script, or paste one in.")
                    .font(Type.body)
                    .foregroundStyle(Label.dim)
                    .padding(.top, 8)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $text)
                .font(Type.body)
                .foregroundStyle(Label.primary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 320)
        }
    }
}

/// The video, floating over the script.
private struct SourceChip: View {
    let item: Item
    let loader: ThumbnailLoader?

    @State private var image: UIImage?

    private var ground: Color {
        guard let packed = item.averageColor else { return Surface.elevated }
        let (r, g, b) = AverageColor.components(packed)
        return Color(.sRGB, red: r, green: g, blue: b)
    }

    var body: some View {
        ZStack {
            ground
            if let image {
                Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                Text(item.platform.displayName.prefix(2).uppercased())
                    .font(Type.meta(10))
                    .foregroundStyle(Label.tertiary)
            }
        }
        .frame(width: 74, height: 104)
        .tileShape(.control)
        .shadow(color: .black.opacity(0.16), radius: 12, y: 4)
        .task(id: item.id) {
            guard let loader, let id = item.id, item.thumbnailState == .stored else { return }
            image = await loader.image(for: id)
        }
    }
}
