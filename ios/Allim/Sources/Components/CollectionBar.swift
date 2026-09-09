import SwiftUI
import AllimDesign

/// The filter above the grid.
///
/// A menu rather than a scrolling row of chips: a real library has hundreds of authors, and a
/// horizontal strip of them turns finding one into a scrubbing exercise. The menu is sorted by
/// how much of the library each author owns, so the ones worth filtering to are at the top.
struct CollectionBar: View {
    let authors: [AuthorGroup]
    let total: Int
    let selected: String?
    let onSelect: (String?) -> Void

    private var label: String { selected ?? "All" }
    private var count: Int { selected.flatMap { name in authors.first { $0.name == name }?.count } ?? total }

    var body: some View {
        HStack(spacing: Space.snug) {
            Menu {
                Button {
                    onSelect(nil)
                } label: {
                    Label("All  ·  \(total)", systemImage: selected == nil ? "checkmark" : "")
                }
                if !authors.isEmpty {
                    Divider()
                    ForEach(authors) { author in
                        Button {
                            onSelect(author.name)
                        } label: {
                            Label("\(author.name)  ·  \(author.count)",
                                  systemImage: selected == author.name ? "checkmark" : "")
                        }
                    }
                }
            } label: {
                HStack(spacing: Space.tight) {
                    Text(label)
                        .font(Type.feature(19))
                        .foregroundStyle(Label.primary)
                        .lineLimit(1)
                    Text("\(count)")
                        .font(Type.meta(10))
                        .foregroundStyle(Label.tertiary)
                        .padding(.horizontal, Space.snug)
                        .padding(.vertical, 2)
                        .background(Surface.elevated, in: Capsule())
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Label.tertiary)
                }
            }
            .accessibilityLabel("Filter by author, currently \(label)")

            Spacer(minLength: 0)

            if selected != nil {
                Button {
                    onSelect(nil)
                } label: {
                    Text("Clear")
                        .font(Type.caption)
                        .foregroundStyle(Label.tertiary)
                }
            }
        }
        .padding(.horizontal, Space.roomy)
        .padding(.vertical, Space.base)
    }
}
