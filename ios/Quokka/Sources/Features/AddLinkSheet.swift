import SwiftUI
import QuokkaDesign

/// Adding by link: one post, or a whole board or channel.
///
/// A field, the system Paste button -- which reads the clipboard without the "Allow Paste"
/// prompt, because the tap itself is the permission -- and one blue Add. Under it, what each
/// kind of link does, so pasting a Pinterest board and getting twenty-five pictures is
/// something a person knows they can do rather than something they stumble on.
struct AddLinkSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    var onImport: () -> Void = {}

    @State private var text = ""
    @State private var working = false
    @State private var result: AppState.AddLinkResult?
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.loose) {
                    Text("Add a link")
                        .font(Type.hand(32))
                        .foregroundStyle(Label.primary)

                    VStack(spacing: Space.base) {
                        HStack(spacing: Space.snug) {
                            Image(systemName: "link")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Label.secondary)
                            TextField("Paste a video, a board or a channel", text: $text)
                                .font(Type.field)
                                .keyboardType(.URL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($focused)
                                .submitLabel(.go)
                                .onSubmit(add)
                            PasteButton(payloadType: String.self) { strings in
                                guard let first = strings.first else { return }
                                Task { @MainActor in
                                    text = first
                                    add()
                                }
                            }
                            .labelStyle(.iconOnly)
                            .buttonBorderShape(.capsule)
                            .tint(Sky.accent)
                        }
                        .padding(.leading, Space.roomy)
                        .padding(.trailing, Space.snug)
                        .frame(height: Control.fieldHeight + 4)
                        .background(Surface.raised, in: Capsule())
                        .overlay(Capsule().stroke(Surface.hairline, lineWidth: Stroke.thin))

                        Button(action: add) {
                            FilledPill(title: working ? "Adding…" : "Add", icon: working ? nil : "plus")
                        }
                        .buttonStyle(PressStyle())
                        .disabled(working || text.trimmingCharacters(in: .whitespaces).isEmpty)
                        .opacity(text.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)

                        if let result { outcome(result) }
                    }

                    VStack(alignment: .leading, spacing: Space.base) {
                        SectionLabel(text: "What you can paste")
                        Card(padding: Space.roomy) {
                            VStack(alignment: .leading, spacing: Space.roomy) {
                                kind("play.rectangle.fill", "A video",
                                     "YouTube, TikTok, Instagram, Reddit, Vimeo. Saved with its picture and title, ready to transcribe.")
                                kind("pin.fill", "A Pinterest board or profile",
                                     "Brings in its latest 25 pins, each with its picture.")
                                kind("square.grid.3x3.fill", "An Are.na channel",
                                     "Brings in up to 100 of its pictures.")
                                kind("safari.fill", "Any web page",
                                     "Saved with the preview image the page publishes.")
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: Space.base) {
                        SectionLabel(text: "Or bring everything")
                        Button {
                            dismiss()
                            onImport()
                        } label: {
                            Card(padding: Space.roomy) {
                                HStack(spacing: Space.base) {
                                    Image(systemName: "square.and.arrow.down.fill")
                                        .font(.system(size: 18))
                                        .foregroundStyle(Sky.accent)
                                        .frame(width: 28)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Import your Instagram")
                                            .font(Type.bodyEmphasis)
                                            .foregroundStyle(Label.primary)
                                        Text("Saved, liked and sent-to-yourself, from Instagram’s own export.")
                                            .font(Type.caption)
                                            .foregroundStyle(Label.secondary)
                                            .multilineTextAlignment(.leading)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Label.dim)
                                }
                            }
                        }
                        .buttonStyle(PressStyle())
                    }
                }
                .padding(.horizontal, Space.gutter)
                .padding(.vertical, Space.loose)
            }
            .background(Surface.canvas)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.font(Type.control)
                }
            }
        }
        .tint(Label.primary)
        .presentationDetents([.large])
        .onAppear { focused = true }
    }

    private func kind(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: Space.base) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Sky.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Type.bodyEmphasis)
                    .foregroundStyle(Label.primary)
                Text(detail)
                    .font(Type.caption)
                    .foregroundStyle(Label.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func outcome(_ result: AppState.AddLinkResult) -> some View {
        let (icon, message, good): (String, String, Bool) = {
            switch result {
            case .saved: return ("checkmark.circle.fill", "Saved. Its picture and title are on the way.", true)
            case .alreadySaved: return ("checkmark.circle", "Already in your library.", true)
            case .collection(let name, let added, let found):
                let already = found - added
                let tail = already > 0 ? " \(already) were already here." : ""
                return ("checkmark.circle.fill", "Added \(added) from \(name).\(tail)", true)
            case .notALink: return ("exclamationmark.circle", "That isn’t a link Quokka can save.", false)
            case .failed(let reason): return ("exclamationmark.circle", reason, false)
            }
        }()
        HStack(alignment: .top, spacing: Space.snug) {
            Image(systemName: icon)
                .foregroundStyle(good ? Sky.accent : Label.secondary)
            Text(message)
                .font(Type.captionEmphasis)
                .foregroundStyle(Label.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(Space.base)
        .background(good ? Sky.tint : Surface.field, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
        .transition(.opacity)
    }

    private func add() {
        let raw = text
        guard !raw.trimmingCharacters(in: .whitespaces).isEmpty, !working else { return }
        working = true
        focused = false
        Task {
            let outcome = await state.addLink(raw)
            withAnimation(Motion.respecting(.easeOut(duration: 0.2))) { result = outcome }
            working = false
            switch outcome {
            case .saved, .collection:
                Haptics.shared.saved()
                text = ""
            case .alreadySaved:
                Haptics.shared.tick()
            case .notALink, .failed:
                Haptics.shared.rejected()
            }
        }
    }
}
