#!/usr/bin/env swift
// Renders Quokka's mark -- the black square with two eyes and a smile, from
// assets/logo/quokka-mark.png -- at every size the app and the Chrome extension need.
//
//   swift scripts/render-icon.swift
//
// Drawn in code rather than exported from the master bitmap so every size is sharp and the
// app icon, the extension icon and the in-app `QuokkaMark` share one set of proportions.
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
    /// The black square's side as a share of the canvas. The app icon keeps white around the
    /// mark, as the master does; toolbar icons fill the canvas or the face is lost at 16px.
    let square: CGFloat
}

let targets = [
    Target(path: "ios/Quokka/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png", size: 1024, square: 0.62),
    Target(path: "extension/icons/icon-128.png", size: 128, square: 0.78),
    Target(path: "extension/icons/icon-48.png", size: 48, square: 1),
    Target(path: "extension/icons/icon-32.png", size: 32, square: 1),
    Target(path: "extension/icons/icon-16.png", size: 16, square: 1),
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

    // The mark, in a square of side `side * target.square`, centred. Proportions match
    // QuokkaMark.swift: eyes 13.3% of the side at 25% / 75% across and 51.3% down; the smile a
    // round-capped quadratic from 42.2% to 57.2% across at 59.6% down, dipping to 64.2%.
    let mark = CGFloat(side) * target.square
    let origin = (CGFloat(side) - mark) / 2
    // Core Graphics counts y from the bottom; the proportions count from the top.
    func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: origin + mark * x, y: origin + mark * (1 - y))
    }

    context.setFillColor(CGColor(red: 0x0A / 255, green: 0x0A / 255, blue: 0x0A / 255, alpha: 1))
    context.fill(CGRect(x: origin, y: origin, width: mark, height: mark))

    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    let eye = mark * 0.133
    for centreX in [0.2495, 0.7475] as [CGFloat] {
        let centre = point(centreX, 0.513)
        context.fillEllipse(in: CGRect(x: centre.x - eye / 2, y: centre.y - eye / 2, width: eye, height: eye))
    }

    context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.setLineWidth(mark * 0.0627)
    context.setLineCap(.round)
    context.move(to: point(0.422, 0.596))
    context.addQuadCurve(to: point(0.572, 0.596), control: point(0.497, 0.642))
    context.strokePath()

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
