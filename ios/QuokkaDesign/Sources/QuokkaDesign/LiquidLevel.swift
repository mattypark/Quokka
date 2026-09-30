import SwiftUI

/// The sky as a liquid: a region anchored to the top of the screen whose bottom edge is a
/// moving wave.
///
/// `level` is how much of the screen the sky covers -- 1 is all of it, 0 is none. Animating it
/// down drains the sky upward, off the top; animating it up pours it back down. The wave is
/// tallest mid-way and flat at rest, and its phase travels with the level, so the edge ripples
/// as it moves instead of sliding like a curtain.
public struct LiquidLevel: Shape {
    public var level: CGFloat

    public init(level: CGFloat) {
        self.level = level
    }

    public var animatableData: CGFloat {
        get { level }
        set { level = newValue }
    }

    public func path(in rect: CGRect) -> Path {
        let clamped = min(max(level, 0), 1)
        // Overshoots the height a little so a full level leaves no sliver of wave showing.
        let base = (rect.height + 60) * clamped
        let swell = sin(.pi * clamped)
        let amplitude = min(rect.height * 0.05, 42) * swell
        let phase = clamped * .pi * 3
        let wavelength = rect.width * 0.95

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        let steps = 60
        for step in stride(from: steps, through: 0, by: -1) {
            let x = rect.minX + rect.width * CGFloat(step) / CGFloat(steps)
            let angle = 2 * .pi * (x - rect.minX) / wavelength + phase
            // Two harmonics, so the edge reads as water rather than as a sine curve.
            let wave = 0.72 * sin(angle) + 0.28 * sin(angle * 2.3 + 1.1)
            path.addLine(to: CGPoint(x: x, y: rect.minY + base - 30 + amplitude * wave))
        }
        path.closeSubpath()
        return path
    }
}

#Preview {
    VStack(spacing: 12) {
        ForEach([0.25, 0.5, 0.75], id: \.self) { level in
            SkyBackground(showsSun: true)
                .mask(LiquidLevel(level: level))
                .frame(height: 200)
                .background(Color(white: 0.95))
        }
    }
}
