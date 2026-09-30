import SwiftUI

/// The sky behind Quokka's headers: a blue gradient with a soft light in the upper corner and
/// a shade low down, so white text clears 4.5:1 wherever it sits.
///
/// Nudgy's header is the real sky over you, keyed to the sun. Quokka's is one fixed daylight
/// sky -- the same blue every time you open it is part of how the app is recognised, and a
/// library tool has no reason to know what time it is.
public struct SkyBackground: View {
    public init() {}

    public var body: some View {
        ZStack {
            LinearGradient(colors: [Sky.top, Sky.mid, Sky.bottom], startPoint: .top, endPoint: .bottom)
            // Daylight from the top right, where a sun would be at mid-morning.
            RadialGradient(
                colors: [Color.white.opacity(0.28), .clear],
                center: UnitPoint(x: 0.85, y: 0.05),
                startRadius: 0,
                endRadius: 260)
            LinearGradient(colors: [.clear, Sky.shade], startPoint: .center, endPoint: .bottom)
        }
        .accessibilityHidden(true)
    }
}

/// A rectangle with only its bottom corners rounded -- the header's shape.
public struct HeaderShape: Shape {
    public var radius: CGFloat

    public init(radius: CGFloat = Radius.header) { self.radius = radius }

    public func path(in rect: CGRect) -> Path {
        UnevenRoundedRectangle(
            bottomLeadingRadius: radius, bottomTrailingRadius: radius, style: .continuous
        ).path(in: rect)
    }
}

public extension View {
    /// Sets this view on the sky, ignoring the top safe area so the blue runs under the
    /// status bar, with the bottom corners rounded.
    func skyHeader() -> some View {
        background(alignment: .top) {
            SkyBackground()
                .clipShape(HeaderShape())
                .ignoresSafeArea(edges: .top)
        }
    }
}
