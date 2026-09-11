import SwiftUI
import AllimDesign
import AllimEngine
import AllimImaging

/// The screen the product is actually for.
///
/// Everything else in Allim exists to get a person here: a script they can copy, with the
/// videos that inspired it kept beside it. Saving is table stakes.
struct IdeaDetailView: View {
    let ideaID: Int64

    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss

    @State private var idea: Idea?
    @State private var sources: [Item] = []
    @State private var pane: Pane = .note
    @State private var copied = false

    private enum Pane: Hashable { case note, inspiration }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomLeading) {
                Surface.canvas.ignoresSafeArea()

                VStack(spacing: 0) {
                    SegmentedTabs(
                        options: [(.note, "Note"), (.inspiration, "Inspiration")],
                        selection: $pane
                    )
                    .frame(width: 220)
                    .padding(.top, Space.snug)
                    .padding(.bottom, Space.base)

                    switch pane {
                    case .note: note
                    case .inspiration: inspiration
                    }
                }

                // The video sits ON the script, bottom-left, rather than above or beside it.
                // That single overlap is what makes the screen read as derived from a video
                // instead of as a document that happens to have one attached.
                if pane == .note, let first = sources.first {
                    SourceChip(item: first, loader: state.loader)
                        .padding(.leading, Space.roomy)
                        .padding(.bottom, 68)
                        .transition(.opacity)
                }

                toolbar
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
        ScrollView(showsIndicators: false) {
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
                                .foregroundStyle(copied ? Label.primary : Label.tertiary)
                                .frame(width: 32, height: 32)
                                .background(Surface.raised, in: Circle())
                        }
                        .accessibilityLabel(copied ? "Copied" : "Copy script")
                    }
                }

                if let hook = idea?.hook, !hook.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("HOOK")
                            .font(Type.meta(9))
                            .foregroundStyle(Label.dim)
                        Text(hook)
                            .font(Type.bodyEmphasis)
                            .foregroundStyle(Label.primary)
                    }
                    .padding(Space.base)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Surface.raised)
                    .tileShape(.control, stroked: false)
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
                    .padding(.horizontal, Space.roomy)
                    .padding(.bottom, 120)
                }
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: Space.loose) {
            ForEach(["chevron.up", "paperclip", "tag", "calendar"], id: \.self) { icon in
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .foregroundStyle(Label.tertiary)
            }
            Spacer()
            Image(systemName: "paperplane")
                .font(.system(size: 17))
                .foregroundStyle(Label.tertiary)
        }
        .padding(.horizontal, Space.roomy)
        .padding(.vertical, Space.base)
        .background(.regularMaterial)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .ignoresSafeArea(edges: .bottom)
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
