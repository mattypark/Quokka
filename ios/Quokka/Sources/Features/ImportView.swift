import SwiftUI
import UniformTypeIdentifiers
import QuokkaDesign
import QuokkaEngine

/// Bringing an Instagram history into Quokka.
///
/// Three steps, each of which has to be legible on its own, because this is the one screen a
/// person uses once and never returns to: choose the folder, choose which conversation, import.
struct ImportView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss

    @State private var pickingFolder = false
    @State private var root: URL?
    @State private var contents: ExportScanner.Contents?
    @State private var selectedThread: InstagramExport.Thread?
    @State private var includeSaved = true
    @State private var includeLiked = true
    @State private var scanning = false
    @State private var importing = false
    @State private var result: ImportResult?

    struct ImportResult { let found: Int; let added: Int }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.loose) {
                    if let result {
                        summary(result)
                    } else if importing {
                        importingState
                    } else if scanning {
                        scanningState
                    } else if let contents {
                        chooser(contents)
                    } else {
                        instructions
                    }
                }
                .padding(Space.roomy)
            }
            .background(Surface.canvas)
            .navigationTitle("Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Surface.canvas, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.font(Type.control)
                }
            }
        }
        .tint(Label.primary)
        .fileImporter(
            isPresented: $pickingFolder,
            // A folder, not a zip. iOS Files unzips natively, so Quokka needs no archive
            // dependency and never has to hold a multi-gigabyte export in memory.
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { outcome in
            guard case .success(let urls) = outcome, let picked = urls.first else { return }
            root = picked
            scan(picked)
        }
    }

    // MARK: - Steps

    private var instructions: some View {
        VStack(alignment: .leading, spacing: Space.roomy) {
            HStack(alignment: .bottom, spacing: Space.base) {
                Text("Bring your Instagram history in")
                    .font(Type.title(24))
                    .foregroundStyle(Label.primary)
            }

            Text("Everything you have ever sent yourself, saved, or liked — in one pass. Quokka reads the file Instagram gives you. It never signs in to your account and never touches your DMs directly.")
                .font(Type.body)
                .foregroundStyle(Label.secondary)

            VStack(alignment: .leading, spacing: Space.base) {
                Step(number: 1, text: "Instagram app → your profile → the ☰ menu → **Accounts Centre** → **Your information and permissions** → **Download your information**.")
                Step(number: 2, text: "Request a download of **Instagram only**. Choose **JSON**, not HTML — Quokka cannot read HTML. Date range: **All time**.")
                Step(number: 3, text: "Instagram emails a link, usually within a few hours. Download the zip on your phone.")
                Step(number: 4, text: "In **Files**, long-press the zip and tap **Uncompress**.")
                Step(number: 5, text: "Come back here and choose that unzipped folder.")
            }

            Button {
                pickingFolder = true
            } label: {
                Text(scanning ? "Reading…" : "Choose the folder")
                    .font(Type.control)
                    .foregroundStyle(Label.onInverse)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Space.base)
                    .background(Label.primary, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
            }
            .disabled(scanning)
        }
    }

    /// Scanning an export walks thousands of files and takes real seconds, so it gets a
    /// character rather than a spinner. A spinner says the system is busy; this says something
    /// is being worked through, which is what is actually happening.
    private var scanningState: some View {
        VStack(spacing: Space.base) {
            Text("reading your export…")
                .font(Type.body)
                .foregroundStyle(Label.secondary)
            Text("This can take a minute on a big one.")
                .font(Type.caption)
                .foregroundStyle(Label.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.chapter)
    }

    private var importingState: some View {
        VStack(spacing: Space.base) {
            Text("bringing them in…")
                .font(Type.body)
                .foregroundStyle(Label.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.chapter)
    }

    @ViewBuilder
    private func chooser(_ contents: ExportScanner.Contents) -> some View {
        VStack(alignment: .leading, spacing: Space.roomy) {
            Text("Which conversation?")
                .font(Type.title(24))
                .foregroundStyle(Label.primary)

            if contents.threads.isEmpty {
                Text("No conversations with shared posts turned up in that folder. Check it is the unzipped export and that you chose JSON rather than HTML.")
                    .font(Type.body)
                    .foregroundStyle(Label.secondary)
            } else {
                Text("Sorted by how many posts each holds. The account you send reels to is almost certainly at the top.")
                    .font(Type.caption)
                    .foregroundStyle(Label.secondary)

                VStack(spacing: Space.tight) {
                    ForEach(contents.threads.prefix(12)) { thread in
                        ThreadRow(thread: thread, selected: selectedThread?.id == thread.id) {
                            selectedThread = selectedThread?.id == thread.id ? nil : thread
                        }
                    }
                }

                Toggle(isOn: $includeSaved) {
                    Text("Also import Saved (\(contents.savedCount))").font(Type.body)
                }
                Toggle(isOn: $includeLiked) {
                    Text("Also import Liked (\(contents.likedCount))").font(Type.body)
                }
            }

            Button {
                runImport()
            } label: {
                Text(importing ? "Importing…" : "Import")
                    .font(Type.control)
                    .foregroundStyle(Label.onInverse)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Space.base)
                    .background(Label.primary, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
            }
            .disabled(importing || (selectedThread == nil && !includeSaved && !includeLiked))
        }
        .tint(Label.primary)
    }

    private func summary(_ result: ImportResult) -> some View {
        VStack(alignment: .leading, spacing: Space.base) {
            Text("Done")
                .font(Type.title(24))
                .foregroundStyle(Label.primary)
            // Both numbers, always. "3,412 added" alone reads as a loss when an export holds
            // 4,600 posts; the gap is duplicates the library already had, which is the system
            // working rather than failing.
            Text("\(result.found) posts found, \(result.added) added.")
                .font(Type.body)
                .foregroundStyle(Label.secondary)
            if result.found > result.added {
                Text("\(result.found - result.added) were already in your library — the same reel usually turns up in a DM, in Saved and in Liked.")
                    .font(Type.caption)
                    .foregroundStyle(Label.tertiary)
            }
            Button("Done") { dismiss() }
                .font(Type.control)
                .padding(.top, Space.base)
        }
    }

    // MARK: - Work

    private func scan(_ url: URL) {
        scanning = true
        Task.detached(priority: .userInitiated) {
            let found = ExportScanner().scan(root: url)
            await MainActor.run {
                contents = found
                selectedThread = found.threads.first
                scanning = false
            }
        }
    }

    private func runImport() {
        guard let root, let contents else { return }
        importing = true
        let account = selectedThread?.title
        let saved = includeSaved
        let liked = includeLiked

        Task.detached(priority: .userInitiated) {
            let shares = ExportScanner().shares(
                from: contents, root: root, account: account, includeSaved: saved, includeLiked: liked
            )
            let items = InstagramExport.items(from: shares)
            let added = await state.importItems(items)
            await MainActor.run {
                result = ImportResult(found: items.count, added: added)
                importing = false
            }
        }
    }
}

private struct Step: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: Space.base) {
            Text("\(number)")
                .font(Type.meta(11))
                .foregroundStyle(Label.tertiary)
                .frame(width: 16, alignment: .leading)
            Text(.init(text))
                .font(Type.caption)
                .foregroundStyle(Label.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ThreadRow: View {
    let thread: InstagramExport.Thread
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(thread.title)
                        .font(Type.body)
                        .foregroundStyle(Label.primary)
                        .lineLimit(1)
                    Text("\(thread.shareCount) shared posts")
                        .font(Type.meta(10))
                        .foregroundStyle(Label.tertiary)
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark").font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Label.primary)
                }
            }
            .padding(Space.base)
            .background(selected ? Surface.elevated : Surface.raised, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    .stroke(selected ? Surface.border : Surface.hairline, lineWidth: Stroke.thin)
            )
        }
        .buttonStyle(.plain)
    }
}
