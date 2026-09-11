import SwiftUI

/// The one place a tile's outline is decided.
///
/// Quokka will eventually offer organic, irregular tile shapes -- Matthew is designing those
/// himself. The seam exists now so that adding them later is one file rather than fifty call
/// sites, and so nothing in a view ever constructs a shape directly.
///
/// `.organic` is declared but deliberately renders as `.minimal` today. A case that exists and
/// falls back is honest; a case that does not exist means every call site has to be revisited
/// when it arrives.
public enum TileStyle: String, Codable, Sendable, CaseIterable {
    case minimal
    case organic

    public var title: String {
        switch self {
        case .minimal: "Minimal"
        case .organic: "Organic"
        }
    }

    public var detail: String {
        switch self {
        case .minimal: "Squares, rectangles and circles."
        case .organic: "Irregular shapes. Coming soon."
        }
    }

    public var isAvailable: Bool { self == .minimal }
}

/// Where a shape is being used. Different roles want different corner treatments, and naming
/// the role rather than passing a radius is what keeps those consistent across screens.
public enum TileRole {
    case tile
    case cover
    case control
    case sheet
    case circle

    var radius: CGFloat {
        switch self {
        case .tile: Radius.card
        case .cover: Radius.card
        case .control: Radius.control
        case .sheet: Radius.sheet
        case .circle: Radius.pill
        }
    }
}

public enum Tiles {
    /// The current style. Read from defaults so a Settings toggle can change it app-wide
    /// without every view holding its own copy.
    @MainActor
    public static var style: TileStyle {
        get {
            let raw = UserDefaults.standard.string(forKey: "quokkaTileStyle") ?? ""
            let stored = TileStyle(rawValue: raw) ?? .minimal
            // Falls back rather than trusting the stored value: organic is selectable in the
            // model but not yet drawable, and a half-built shape is worse than a square one.
            return stored.isAvailable ? stored : .minimal
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "quokkaTileStyle") }
    }

    /// The outline for a role, in the current style.
    @MainActor
    public static func shape(_ role: TileRole) -> AnyShape {
        switch style {
        case .minimal, .organic:
            AnyShape(RoundedRectangle(cornerRadius: role.radius, style: .continuous))
        }
    }
}

public extension View {
    /// Clips to the current tile shape and draws its hairline in one call, so the two can
    /// never disagree about the radius.
    @MainActor
    func tileShape(_ role: TileRole = .tile, stroked: Bool = true) -> some View {
        let shape = Tiles.shape(role)
        return clipShape(shape)
            .overlay(stroked ? shape.stroke(Surface.hairline, lineWidth: Stroke.thin) : nil)
    }
}
