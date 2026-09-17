import SwiftUI
import QuokkaDesign

struct SettingsView: View {
    /// Settings is a tab now, not a sheet, so it must not draw its own dismiss button when it
    /// is embedded -- a Done button that closes nothing is worse than no button.
    var embedded = false

    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss

    @State private var mirrors = false
    @State private var haptics = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.loose) {
                    Toggle(isOn: $haptics) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Haptics").font(Type.body).foregroundStyle(Label.primary)
                            Text("The taps as the name spells itself out, and when a save lands.")
                                .font(Type.caption).foregroundStyle(Label.tertiary)
                        }
                    }
                    .onChange(of: haptics) { _, on in Haptics.shared.enabled = on }

                    Divider().overlay(Surface.hairline)

                    Toggle(isOn: $mirrors) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Let Claude read your library").font(Type.body).foregroundStyle(Label.primary)
                            // The honest description of what switching this on actually does,
                            // in the place where the decision is made rather than buried in a
                            // policy nobody opens.
                            Text("Writes a copy of your saved links, authors and notes to a file on your device — in iCloud Drive if it is available. Claude Code on your Mac can then read it and write tags back. No account, no API key, and nothing is sent to a server.")
                                .font(Type.caption).foregroundStyle(Label.tertiary)
                        }
                    }
                    .onChange(of: mirrors) { _, on in state.mirrorsToClaude = on }

                    if mirrors {
                        VStack(alignment: .leading, spacing: Space.snug) {
                            Text("ON YOUR MAC")
                                .font(Type.meta(9)).foregroundStyle(Label.dim)
                            Text("claude mcp add quokka -- node ~/quokka-mcp/index.mjs")
                                .font(Type.meta(11))
                                .foregroundStyle(Label.secondary)
                                .textSelection(.enabled)
                                .padding(Space.base)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Surface.raised, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                        }
                    }

                    Divider().overlay(Surface.hairline)

                    VStack(alignment: .leading, spacing: Space.tight) {
                        Text("\(state.total) saved").font(Type.body).foregroundStyle(Label.primary)
                        Text("Quokka keeps everything on this device. Nothing is uploaded.")
                            .font(Type.caption).foregroundStyle(Label.tertiary)
                    }

                    Divider().overlay(Surface.hairline)

                    // Apple requires the privacy policy to be reachable from inside the app as
                    // well as from the App Store listing, and a reviewer who cannot find it
                    // cites the app rather than going looking.
                    HStack(spacing: Space.loose) {
                        Link("Privacy Policy", destination: Legal.privacy)
                        Link("Terms", destination: Legal.terms)
                        Link("Support", destination: Legal.support)
                    }
                    .font(Type.control)
                    .foregroundStyle(Label.secondary)
                }
                .padding(Space.roomy)
                .padding(.bottom, Grid.bottomInset)
            }
            .background(Surface.canvas)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Surface.canvas, for: .navigationBar)
            .toolbar {
                if !embedded {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }.font(Type.control)
                    }
                }
            }
        }
        .tint(Label.primary)
        .onAppear {
            mirrors = state.mirrorsToClaude
            haptics = Haptics.shared.enabled
        }
    }
}
