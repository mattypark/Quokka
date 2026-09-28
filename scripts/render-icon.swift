#!/usr/bin/env swift
// Renders Quokka's mark -- a black lowercase "q" in SF Pro on white -- at every size the app
// and the Chrome extension need.
//
//   swift scripts/render-icon.swift
//
// Drawn in code rather than exported from a design file so the icon is reproducible from the
// repo alone, and so the app icon and the extension's toolbar icon cannot drift apart.
//
// The PNGs are written with no alpha channel. App Store Connect rejects a marketing icon that
// has one, even a fully opaque one.

import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: CommandLine.arguments[0])
    .deletingLastPathComponent()
    .deletingLastPathComponent()

struct Target {
    let path: String
    let size: Int
    /// Small toolbar icons get a heavier weight, or the counter of the "q" closes up at 16px.
    let weight: NSFont.Weight
}

let targets = [
    Target(path: "ios/Quokka/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png", size: 1024, weight: .semibold),
    Target(path: "extension/icons/icon-128.png", size: 128, weight: .semibold),
    Target(path: "extension/icons/icon-48.png", size: 48, weight: .bold),
    Target(path: "extension/icons/icon-32.png", size: 32, weight: .bold),
    Target(path: "extension/icons/icon-16.png", size: 16, weight: .heavy),
]

func render(_ target: Target) throws {
    let side = target.size
    guard let context = CGContext(
        data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
    else { throw NSError(domain: "render-icon", code: 1) }

    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: side, height: side))

    let graphics = NSGraphicsContext(cgContext: context, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics

    let font = NSFont.systemFont(ofSize: CGFloat(side) * 0.74, weight: target.weight)
    let ink = NSColor(srgbRed: 0x0A / 255, green: 0x0A / 255, blue: 0x0A / 255, alpha: 1)
    let glyph = NSAttributedString(string: "q", attributes: [.font: font, .foregroundColor: ink])

    // Centred on the glyph's own ink rather than its line box: a "q" is all x-height and
    // descender, so centring the line box would sit it visibly high.
    let line = CTLineCreateWithAttributedString(glyph)
    let inkBounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
    let x = (CGFloat(side) - inkBounds.width) / 2 - inkBounds.minX
    let y = (CGFloat(side) - inkBounds.height) / 2 - inkBounds.minY
    context.textPosition = CGPoint(x: x, y: y)
    CTLineDraw(line, context)

    NSGraphicsContext.restoreGraphicsState()

    guard let image = context.makeImage() else { throw NSError(domain: "render-icon", code: 2) }
    let url = root.appendingPathComponent(target.path)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { throw NSError(domain: "render-icon", code: 3) }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw NSError(domain: "render-icon", code: 4) }
    print("wrote \(target.path)")
}

for target in targets {
    try render(target)
}
