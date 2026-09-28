import SwiftUI
import QuokkaDesign
import QuokkaEngine

/// The other half of the app: what you are going to make, and when.
///
/// The library is what you collected. This is the working surface -- the ideas you have said
/// you will post, the ones you finished, and the ones you decided against. Skipped is a first
/// class outcome rather than a deletion, because deciding not to make something is a decision
/// worth keeping.
///
/// A pane inside the profile's Ideas tab since the Cosmos redesign, which has no planner of
/// its own. So it draws no scroll view and no screen title; the profile owns both.
struct IdeasPane: View {
    @Environment(AppState.self) private var state

    @State private var selectedDay = Date()
    @State private var lane: Lane = .todo
    @State private var journal = ""
    @State private var openIdea: Int64?

    private enum Lane: Hashable, CaseIterable {
        case todo, completed, skipped

        var status: Idea.Status {
            switch self {
            case .todo: .todo
            case .completed: .completed
            case .skipped: .skipped
            }
        }

        var title: String {
            switch self {
            case .todo: "To-dos"
            case .completed: "Completed"
            case .skipped: "Skipped"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.roomy) {
            dayHeader
            weekStrip
            lanePicker
            laneContents
            journalPrompt
        }
        .sheet(item: Binding(get: { openIdea.map(Opened.init) }, set: { openIdea = $0?.id })) { opened in
            IdeaDetailView(ideaID: opened.id)
        }
        .task { journal = state.journal(for: selectedDay) }
        .onChange(of: selectedDay) { _, day in journal = state.journal(for: day) }
    }

    private struct Opened: Identifiable { let id: Int64 }

    // MARK: - Header

    private var dayHeader: some View {
        Text(selectedDay.formatted(.dateTime.weekday(.wide).day().month(.wide)))
            .font(Type.title(20))
            .foregroundStyle(Label.primary)
            .padding(.horizontal, Space.roomy)
            .padding(.top, Space.roomy)
    }

    /// Seven days ending today, so the strip is a week of history rather than a calendar that
    /// invites planning into a future the app cannot help with yet.
    private var weekStrip: some View {
        let calendar = Calendar.current
        let days = (0..<7).reversed().compactMap {
            calendar.date(byAdding: .day, value: -$0, to: Date())
        }
        return HStack(spacing: 0) {
            ForEach(days, id: \.self) { day in
                let isSelected = calendar.isDate(day, inSameDayAs: selectedDay)
                Button {
                    Haptics.shared.tick()
                    selectedDay = day
                } label: {
                    Text(day.formatted(.dateTime.day()))
                        .font(Type.meta(14))
                        .foregroundStyle(isSelected ? Label.onInverse : Label.secondary)
                        .frame(width: 34, height: 34)
                        .background {
                            if isSelected { Circle().fill(Surface.inverse) }
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(day.formatted(.dateTime.weekday(.wide).day().month(.wide)))
            }
        }
        .padding(.horizontal, Space.base)
    }

    private var lanePicker: some View {
        TextTabs(options: Lane.allCases.map { (value: $0, title: $0.title) }, selection: $lane)
            .padding(.horizontal, Space.roomy)
    }

    private var laneContents: some View {
        let ideas = state.ideas(status: lane.status)
        return VStack(spacing: Space.snug) {
            if ideas.isEmpty {
                VStack(spacing: Space.base) {
                    Text(emptyText)
                        .font(Type.caption)
                        .foregroundStyle(Label.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Space.loose)
            } else {
                ForEach(ideas) { idea in
                    PlannerRow(
                        idea: idea,
                        onOpen: { openIdea = idea.id },
                        onToggle: { toggle(idea) }
                    )
                }
            }
        }
        .padding(.horizontal, Space.roomy)
    }

    private var emptyText: String {
        switch lane {
        case .todo: "Nothing lined up. Add an idea to a playlist and it shows up here."
        case .completed: "Nothing finished yet."
        case .skipped: "Nothing skipped. Deciding against something counts too."
        }
    }

    /// The journal.
    ///
    /// One row per day, and the prompt is set in the editorial serif at size rather than as a
    /// form label -- it is meant to be answered, not filled in.
    private var journalPrompt: some View {
        VStack(alignment: .leading, spacing: Space.base) {
            Text("What would you want your past self to know?")
                .font(Type.title(20))
                .foregroundStyle(Label.primary)
                .fixedSize(horizontal: false, vertical: true)

            ZStack(alignment: .topLeading) {
                if journal.isEmpty {
                    Text("Add my thoughts here…")
                        .font(Type.body)
                        .foregroundStyle(Label.dim)
                        .padding(.top, 8)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $journal)
                    .font(Type.body)
                    .foregroundStyle(Label.primary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 120)
                    // Saved on every change rather than on a done button, because there is no
                    // moment in a journal where a person decides they are finished.
                    .onChange(of: journal) { _, text in
                        state.setJournal(text, for: selectedDay)
                    }
            }
        }
        .padding(.horizontal, Space.roomy)
        .padding(.top, Space.loose)
    }

    private func toggle(_ idea: Idea) {
        guard let id = idea.id else { return }
        Haptics.shared.saved()
        // To-dos complete; anything already resolved goes back to the list. One control, and
        // its meaning is always "move this out of where it is".
        state.setStatus(idea.status == .todo ? .completed : .todo, forIdea: id)
    }
}

private struct PlannerRow: View {
    let idea: Idea
    let onOpen: () -> Void
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: Space.base) {
            Button(action: onOpen) {
                HStack(spacing: Space.base) {
                    Image(systemName: "music.note")
                        .font(.system(size: 12))
                        .foregroundStyle(Label.tertiary)
                    Text(idea.title)
                        .font(Type.body)
                        .foregroundStyle(idea.status == .skipped ? Label.tertiary : Label.primary)
                        .strikethrough(idea.status == .skipped, color: Label.dim)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onToggle) {
                Image(systemName: idea.status == .completed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(idea.status == .completed ? Label.primary : Label.dim)
            }
            .accessibilityLabel(idea.status == .completed ? "Mark as to-do" : "Mark as done")
        }
        .padding(.vertical, Space.base)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Surface.hairline).frame(height: Stroke.thin)
        }
    }
}
