import SwiftUI

/// The mascot.
///
/// Pixel art, so it is rendered with **nearest-neighbour interpolation** -- SwiftUI's default
/// smoothing turns hard pixel edges into mush at any size above 1x, which is the single fastest
/// way to make pixel art look broken.
public struct QuokkaView: View {
    public enum Pose: String, CaseIterable, Sendable {
        case idle, blink, happy, wink, love

        var asset: String {
            switch self {
            case .idle: "quokka-idle-0"
            case .blink: "quokka-idle-1"
            case .happy: "quokka-happy-0"
            case .wink: "quokka-happy-1"
            case .love: "quokka-love"
            }
        }
    }

    let pose: Pose
    let size: CGFloat

    public init(_ pose: Pose = .idle, size: CGFloat = 96) {
        self.pose = pose
        self.size = size
    }

    public var body: some View {
        Image(pose.asset, bundle: .module)
            .resizable()
            .interpolation(.none)
            .antialiased(false)
            .aspectRatio(contentMode: .fit)
            .frame(height: size)
            .accessibilityHidden(true)
    }
}

/// The mascot, alive.
///
/// Two-frame animation rather than a full sprite loop: the sheet only yielded a handful of
/// frames cleanly, and a slow two-frame breath reads as alive where a fast one reads as a
/// glitch. Held on `idle` under Reduce Motion.
public struct AnimatedQuokka: View {
    public enum Mood: Sendable {
        case idle, thinking, celebrating

        var frames: [QuokkaView.Pose] {
            switch self {
            case .idle: [.idle, .blink]
            case .thinking: [.idle, .happy]
            case .celebrating: [.happy, .wink]
            }
        }

        var interval: Double {
            switch self {
            case .idle: 2.4
            case .thinking: 0.5
            case .celebrating: 0.32
            }
        }
    }

    let mood: Mood
    let size: CGFloat

    @State private var frame = 0

    public init(_ mood: Mood = .idle, size: CGFloat = 96) {
        self.mood = mood
        self.size = size
    }

    public var body: some View {
        QuokkaView(mood.frames[frame % mood.frames.count], size: size)
            .task(id: mood.interval) {
                guard !Motion.reduced else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(mood.interval))
                    frame += 1
                }
            }
    }
}
