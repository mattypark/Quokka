import SwiftUI
import AllimEngine

/// What the share sheet shows. Deliberately tiny: a full-screen takeover for an action that
/// takes 200 ms reads as an interruption, not a confirmation.
struct ShareConfirmation: View {
    enum State { case working, saved, rejected }

    let state: State
    let platform: Platform?

    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: 10) {
                mark
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.black)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(.white.opacity(0.16), lineWidth: 0.5)
                    )
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(state == .working ? 0.0 : 0.28))
        .animation(.easeOut(duration: 0.18), value: state)
    }

    @ViewBuilder
    private var mark: some View {
        switch state {
        case .working:
            ProgressView().tint(.white).scaleEffect(0.8).frame(width: 18, height: 18)
        case .saved:
            Image(systemName: "checkmark").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
        case .rejected:
            Image(systemName: "xmark").font(.system(size: 15, weight: .bold)).foregroundStyle(.white.opacity(0.6))
        }
    }

    private var title: String {
        switch state {
        case .working: "Saving"
        case .saved: "Saved to Allim"
        case .rejected: "Nothing to save"
        }
    }

    private var subtitle: String? {
        switch state {
        case .working: nil
        case .saved: platform?.displayName.lowercased()
        case .rejected: "no link or image in this share"
        }
    }
}
