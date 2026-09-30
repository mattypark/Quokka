import SwiftUI

/// The sky behind Quokka: a blue gradient with a shade low down, so white text clears 4.5:1
/// wherever it sits -- and, when asked, the sun.
///
/// The blue stays the same all day: the same sky every time you open the app is part of how it
/// is recognised. What moves is the sun, which crosses the top of the page with the hour --
/// low on the left in the morning, high and centred at noon, low on the right by evening.
public struct SkyBackground: View {
    var showsSun: Bool

    public init(showsSun: Bool = false) {
        self.showsSun = showsSun
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(colors: [Sky.top, Sky.mid, Sky.bottom], startPoint: .top, endPoint: .bottom)
                if showsSun {
                    SkySun(position: SkySun.position(at: .now, in: proxy.size))
                } else {
                    // Daylight from the top right, where a sun would be at mid-morning.
                    RadialGradient(
                        colors: [Color.white.opacity(0.28), .clear],
                        center: UnitPoint(x: 0.85, y: 0.05),
                        startRadius: 0,
                        endRadius: 260)
                }
                LinearGradient(colors: [.clear, Sky.shade], startPoint: .center, endPoint: .bottom)
            }
        }
        .accessibilityHidden(true)
    }
}

/// The sun: a warm disc in a wide glow, breathing slowly.
struct SkySun: View {
    let position: CGPoint

    @State private var breathing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [Color(hex: 0xFFF3C4).opacity(0.55), Color(hex: 0xFFF3C4).opacity(0.12), .clear],
                    center: .center, startRadius: 0, endRadius: 170))
                .frame(width: 340, height: 340)
                .scaleEffect(breathing ? 1.06 : 0.96)
            Circle()
                .fill(Color(hex: 0xFFF7DE))
                .frame(width: 58, height: 58)
                .blur(radius: 1.5)
                .shadow(color: Color(hex: 0xFFE9A8).opacity(0.9), radius: 24)
        }
        .position(position)
        .onAppear {
            guard !Motion.reduced else { return }
            withAnimation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true)) { breathing = true }
        }
    }

    /// Where the sun sits at a given time: across the top of the page from 6am to 6pm, highest
    /// at noon. Clamped, so before dawn and after dusk it waits at the edges rather than leaving.
    static func position(at date: Date, in size: CGSize, calendar: Calendar = .current) -> CGPoint {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let hours = Double(parts.hour ?? 12) + Double(parts.minute ?? 0) / 60
        let arc = min(max((hours - 6) / 12, 0), 1)
        let height = 1 - abs(arc - 0.5) * 2
        return CGPoint(
            x: size.width * (0.12 + 0.76 * arc),
            y: 70 + (1 - height) * 90)
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
