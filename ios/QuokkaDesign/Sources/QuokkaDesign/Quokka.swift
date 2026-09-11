import SwiftUI

/// The mascot.
///
/// Five animations cut from transparent sprite strips. Rendered with **nearest-neighbour
/// interpolation and antialiasing off** -- SwiftUI's default smoothing turns hard pixel edges
/// into mush at any size above 1x, which is the fastest way to make pixel art look broken.
public struct Quokka: View {

    public enum Animation: String, CaseIterable, Sendable {
        /// Standing, breathing. The resting state.
        case idle
        /// Walking. Reads as working on something.
        case walk
        /// Hearts. For a save landing.
        case love
        /// Cheering, with sparkles.
        case cheer
        /// Asleep. For an empty screen -- nothing to do yet.
        case sleep

        var frameCount: Int {
            switch self {
            case .idle, .walk: 6
            case .love, .sleep: 8
            case .cheer: 7
            }
        }

        /// Seconds per frame.
        ///
        /// Sleep is slow because breathing is; cheer is fast because excitement is. Getting
        /// these wrong is most of the difference between a character and a flickering image.
        var interval: Double {
            switch self {
            case .idle: 0.18
            case .walk: 0.11
            case .love: 0.14
            case .cheer: 0.10
            case .sleep: 0.32
            }
        }

        func asset(_ index: Int) -> String {
            "quokka-\(rawValue)-\(index % frameCount)"
        }
    }

    let animation: Animation
    let size: CGFloat
    /// Stops on the first frame. For a still mascot in a list or a header.
    let animated: Bool

    @State private var frame = 0

    public init(_ animation: Animation = .idle, size: CGFloat = 96, animated: Bool = true) {
        self.animation = animation
        self.size = size
        self.animated = animated
    }

    public var body: some View {
        Image(animation.asset(frame), bundle: .module)
            .resizable()
            .interpolation(.none)
            .antialiased(false)
            .aspectRatio(contentMode: .fit)
            .frame(height: size)
            .accessibilityHidden(true)
            .task(id: animation) {
                // Reduce Motion holds frame zero. A looping character is exactly the kind of
                // persistent movement the preference exists to stop.
                guard animated, !Motion.reduced else { frame = 0; return }
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(animation.interval))
                    frame &+= 1
                }
            }
    }
}
