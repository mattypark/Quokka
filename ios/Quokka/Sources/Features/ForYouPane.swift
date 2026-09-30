import SwiftUI
import QuokkaDesign
import QuokkaEngine

/// "For you": what this person's own saves say about their taste.
///
/// Nobody else's data is in it. It is built on the phone from this library and its breakdowns,
/// and it says so at the top -- then what they are drawn to, in sentences that are counts, the
/// hooks they save as a bar chart, the creators they come back to, their colours, and a hook to
/// try in the shape they save most. With too little to go on it says that instead of guessing.
struct ForYouPane: View {
    @Environment(AppState.self) private var state

    @State private var profile: TasteProfile?
    @State private var colours: [Int] = []
    @State private var openIdea: Int64?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.loose) {
            if let profile {
                header(profile)
                if !profile.notes.isEmpty { notes(profile) }
                if !profile.hooks.isEmpty, !profile.isEarly { hooks(profile) }
                if let shape = profile.suggestedHook, !profile.isEarly { tryThis(shape) }
                if !profile.creators.isEmpty { creators(profile) }
                if !colours.isEmpty { palette }
            }
        }
        .padding(.horizontal, Space.gutter)
        .task { reload() }
        .sheet(item: Binding(get: { openIdea.map(Opened.init) }, set: { openIdea = $0?.id })) { opened in
            IdeaDetailView(ideaID: opened.id)
        }
    }

    private struct Opened: Identifiable { let id: Int64 }

    // MARK: - Pieces

    /// Sky, like Home, so the one screen that is about you has the app's own light on it.
    private func header(_ profile: TasteProfile) -> some View {
        VStack(alignment: .leading, spacing: Space.snug) {
            Text("Your taste")
                .font(Type.hand(32))
                .foregroundStyle(Label.onSky)
            Text(headerLine(profile))
                .font(Type.body)
                .foregroundStyle(Label.onSkySecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Space.tight) {
                Image(systemName: "lock.fill").font(.system(size: 11))
                Text("Read on this phone, from your saves only")
                    .font(Type.captionEmphasis)
            }
            .foregroundStyle(Label.onSkySecondary)
            .padding(.top, Space.tight)
        }
        .padding(Space.loose)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { SkyBackground() }
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }

    private func headerLine(_ profile: TasteProfile) -> String {
        let saves = profile.saves == 1 ? "1 save" : "\(profile.saves) saves"
        let broken = profile.breakdowns == 1 ? "1 breakdown" : "\(profile.breakdowns) breakdowns"
        if profile.isEarly {
            let more = TasteProfile.breakdownsToMatter - profile.breakdowns
            return "From \(saves) and \(broken). Break down \(more) more \(more == 1 ? "video" : "videos") and the patterns start to show."
        }
        return "From \(saves) and \(broken). It gets sharper with every one."
    }

    private func notes(_ profile: TasteProfile) -> some View {
        VStack(alignment: .leading, spacing: Space.base) {
            SectionLabel(text: "What you are drawn to")
            Card(padding: Space.roomy) {
                VStack(alignment: .leading, spacing: Space.roomy) {
                    ForEach(Array(profile.notes.enumerated()), id: \.offset) { _, note in
                        HStack(alignment: .top, spacing: Space.base) {
                            Circle()
                                .fill(Sky.accent)
                                .frame(width: 7, height: 7)
                                .padding(.top, 7)
                            Text(note)
                                .font(Type.body)
                                .foregroundStyle(Label.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    /// The hook kinds as bars, each against the number of breakdowns -- so a bar is a share of
    /// what you broke down, not a share of hooks, and the labels read true.
    private func hooks(_ profile: TasteProfile) -> some View {
        VStack(alignment: .leading, spacing: Space.base) {
            SectionLabel(text: "Hooks you save", trailing: "of \(profile.breakdowns)")
            Card(padding: Space.roomy) {
                VStack(alignment: .leading, spacing: Space.base) {
                    ForEach(profile.hooks, id: \.kind) { share in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(share.kind.label)
                                    .font(Type.captionEmphasis)
                                    .foregroundStyle(Label.primary)
                                Spacer()
                                Text("\(share.count)")
                                    .font(Type.meta(13))
                                    .foregroundStyle(Label.secondary)
                            }
                            GeometryReader { proxy in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Sky.tint)
                                    Capsule()
                                        .fill(Sky.accent)
                                        .frame(width: proxy.size.width * CGFloat(share.count) / CGFloat(max(profile.breakdowns, 1)))
                                }
                            }
                            .frame(height: 8)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(share.kind.label): \(share.count) of \(profile.breakdowns)")
                    }
                }
            }
        }
    }

    private func tryThis(_ shape: String) -> some View {
        VStack(alignment: .leading, spacing: Space.base) {
            SectionLabel(text: "Try this shape")
            Card(padding: Space.roomy) {
                VStack(alignment: .leading, spacing: Space.base) {
                    Text("“\(shape)”")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Label.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("The kind of opening you save most. Fill in the brackets with your own.")
                        .font(Type.caption)
                        .foregroundStyle(Label.secondary)
                    Button { startIdea(shape) } label: {
                        FilledPill(title: "Start an idea with it", icon: "sparkles", tone: .ink)
                    }
                    .buttonStyle(PressStyle())
                    .padding(.top, Space.tight)
                }
            }
        }
    }

    private func creators(_ profile: TasteProfile) -> some View {
        VStack(alignment: .leading, spacing: Space.base) {
            SectionLabel(text: "Creators you come back to")
            Card(padding: Space.base) {
                VStack(spacing: 0) {
                    ForEach(Array(profile.creators.enumerated()), id: \.element.name) { index, creator in
                        NavigationLink(value: Route.creator(creator.name)) {
                            HStack(spacing: Space.base) {
                                Text("\(index + 1)")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(Label.onInverse)
                                    .frame(width: 24, height: 24)
                                    .background(Surface.inverse, in: Circle())
                                Text(creator.name)
                                    .font(Type.bodyEmphasis)
                                    .foregroundStyle(Label.primary)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                                Text(creator.count == 1 ? "1 save" : "\(creator.count) saves")
                                    .font(Type.caption)
                                    .foregroundStyle(Label.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Label.dim)
                            }
                            .padding(.vertical, Space.snug)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var palette: some View {
        VStack(alignment: .leading, spacing: Space.base) {
            SectionLabel(text: "Your colours")
            HStack(spacing: 0) {
                ForEach(colours, id: \.self) { packed in
                    Rectangle().fill(LibraryView.swiftColor(packed))
                }
            }
            .frame(height: 56)
            .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
            .accessibilityLabel("The colours most common in your saved pictures")
        }
    }

    // MARK: - Work

    private func reload() {
        profile = state.tasteProfile()
        colours = state.swatches(count: 8)
    }

    private func startIdea(_ shape: String) {
        guard var idea = state.createIdea(title: shape, playlistID: nil), let id = idea.id else { return }
        idea.hook = shape
        state.save(idea)
        Haptics.shared.saved()
        openIdea = id
    }
}
