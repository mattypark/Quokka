import SwiftUI

/// Quokka's mark: a black square with two round eyes and a smile.
///
/// Drawn as vector shapes rather than shipped as a bitmap, so it is sharp at 16pt in a tab
/// bar and at 1024px on the App Store, and so it can blink. Proportions are measured off
/// Matthew's master in `assets/logo/quokka-mark.png`: eyes 13.3% of the side, centred at
/// 25% and 75% across and 51% down; the smile a round-capped arc 21% wide, a little below.
public struct QuokkaMark: View {
    public enum Style: Sendable {
        /// Black square, white face -- the master.
        case ink
        /// White square, black face -- for dark and sky backgrounds.
        case paper
    }

    var size: CGFloat
    var style: Style
    var blinks: Bool

    public init(size: CGFloat = 32, style: Style = .ink, blinks: Bool = false) {
        self.size = size
        self.style = style
        self.blinks = blinks
    }

    @State private var shut = false

    private var square: Color { style == .ink ? Color(hex: 0x0A0A0A) : .white }
    private var face: Color { style == .ink ? .white : Color(hex: 0x0A0A0A) }

    public var body: some View {
        ZStack {
            Rectangle().fill(square)
            MarkEyes(openness: shut ? 0.12 : 1).fill(face)
            MarkSmile().stroke(face, style: StrokeStyle(lineWidth: size * 0.0627, lineCap: .round))
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Quokka")
        .task {
            // A blink every few seconds, never on a schedule you can feel. Skipped entirely
            // under Reduce Motion.
            guard blinks, !Motion.reduced else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Double.random(in: 2.8...5.5)))
                withAnimation(.easeIn(duration: 0.07)) { shut = true }
                try? await Task.sleep(for: .milliseconds(120))
                withAnimation(.easeOut(duration: 0.11)) { shut = false }
            }
        }
    }
}

/// Both eyes, as one shape so they blink together. Closing squashes each circle to a sliver
/// about its own centre line.
private struct MarkEyes: Shape {
    /// 1 is open, near 0 is shut. Animatable, so a blink is a squash rather than a cut.
    var openness: CGFloat

    var animatableData: CGFloat {
        get { openness }
        set { openness = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let diameter = side * 0.133
        let height = diameter * openness
        var path = Path()
        for centreX in [0.2495, 0.7475] {
            path.addEllipse(in: CGRect(
                x: rect.minX + side * centreX - diameter / 2,
                y: rect.minY + side * 0.513 - height / 2,
                width: diameter,
                height: height))
        }
        return path
    }
}

/// The smile: a quadratic arc whose centre line dips from 59.6% to 61.9% down.
private struct MarkSmile: Shape {
    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + side * 0.422, y: rect.minY + side * 0.596))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + side * 0.572, y: rect.minY + side * 0.596),
            control: CGPoint(x: rect.minX + side * 0.497, y: rect.minY + side * 0.642))
        return path
    }
}

#Preview {
    HStack(spacing: 24) {
        QuokkaMark(size: 120, blinks: true)
        QuokkaMark(size: 120, style: .paper).padding(12).background(Color.black)
        QuokkaMark(size: 24)
    }
}
