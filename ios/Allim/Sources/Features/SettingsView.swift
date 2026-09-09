import SwiftUI
import AllimDesign

struct SettingsView: View {
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
                            Text("claude mcp add allim -- node ~/allim-mcp/index.mjs")
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
                        Text("Allim keeps everything on this device. Nothing is uploaded.")
                            .font(Type.caption).foregroundStyle(Label.tertiary)
                    }
                }
                .padding(Space.roomy)
            }
            .background(Surface.canvas)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Surface.canvas, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.font(Type.control)
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
