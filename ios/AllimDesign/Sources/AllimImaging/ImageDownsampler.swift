import ImageIO
import UniformTypeIdentifiers
import CoreGraphics
import AVFoundation
import Foundation

/// A downsampled thumbnail, with everything the store needs, computed in one pass.
///
/// Size and average colour are returned alongside the bytes rather than derived later on
/// purpose: recovering them would mean decoding the image a second time, and decoding is the
/// expensive half of this whole operation.
public struct Thumbnail: Sendable {
    public let data: Data
    public let width: Int
    public let height: Int
    public let format: String
    /// Packed 0x00RRGGBB. See `AverageColor`.
    public let averageColor: Int?

    public var aspectRatio: Double { height > 0 ? Double(width) / Double(height) : 1 }
}

/// Turns whatever arrived into one small thumbnail, without ever materialising a full bitmap.
///
/// This runs inside an app extension, which is killed at roughly 120 MB
/// (`EXC_RESOURCE RESOURCE_TYPE_MEMORY`). The canonical way to hit that limit is exactly this
/// workload -- decode a `UIImage` from a file, then make a second resized one -- because a
/// decoded bitmap costs width x height x 4 bytes regardless of how small the compressed file
/// was. A 4000x3000 photo is ~48 MB decoded, twice over. ImageIO never decodes the full image
/// at all, so the ceiling is never approached.
public enum ImageDownsampler {

    /// 800px on the long edge: a 400pt tile at 2x, the largest the grid ever shows. Storing
    /// more multiplies the library's footprint for pixels nothing renders.
    public static let maxPixelSize = 800

    public static func thumbnail(from data: Data) -> Thumbnail? {
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
        return encode(downsample(source))
    }

    public static func thumbnail(fromFileAt url: URL) -> Thumbnail? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else { return nil }
        return encode(downsample(source))
    }

    /// Computed, not stored: CFDictionary is not Sendable, so a shared static would be a
    /// concurrency error. Building it costs nothing next to reading the image.
    private static var sourceOptions: CFDictionary { [kCGImageSourceShouldCache: false] as CFDictionary }

    private static func downsample(_ source: CGImageSource) -> CGImage? {
        let options: [CFString: Any] = [
            // Without this, a source with no embedded thumbnail returns nothing at all.
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            // Applies the EXIF orientation now. Skipping it stores sideways photos that every
            // later consumer has to remember to rotate.
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// HEIC where the hardware supports it, JPEG otherwise.
    ///
    /// HEIC is roughly half the size of JPEG at equivalent quality, which halves the library's
    /// footprint -- the difference between ~16 GB and ~30 GB at half a million items. It is
    /// safe here specifically because Allim is device-local: the usual objection, that
    /// browsers cannot decode HEIC, applies to nothing that will ever read these bytes. The
    /// capability is checked rather than assumed, since `CGImageDestination` creation returns
    /// nil on hardware with no HEVC encoder.
    private static func encode(_ image: CGImage?) -> Thumbnail? {
        guard let image else { return nil }
        let quality: CGFloat = 0.8
        let colour = AverageColor.extract(from: image)

        let supportsHEIC = (CGImageDestinationCopyTypeIdentifiers() as? [String])?
            .contains(AVFileType.heic.rawValue) ?? false

        if supportsHEIC, let data = write(image, as: AVFileType.heic.rawValue, quality: quality) {
            return Thumbnail(data: data, width: image.width, height: image.height, format: "heic", averageColor: colour)
        }
        guard let data = write(image, as: UTType.jpeg.identifier, quality: quality) else { return nil }
        return Thumbnail(data: data, width: image.width, height: image.height, format: "jpeg", averageColor: colour)
    }

    private static func write(_ image: CGImage, as type: String, quality: CGFloat) -> Data? {
        guard let out = CFDataCreateMutable(nil, 0),
              let destination = CGImageDestinationCreateWithData(out, type as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return out as Data
    }
}

public enum AverageColor {

    /// The four bytes stored inline on every row, packed 0x00RRGGBB.
    ///
    /// This is the placeholder, and it is deliberately not a ThumbHash or a BlurHash. Those
    /// exist to hide *network* latency, and this architecture has none: the thumbnail is a
    /// local SQLite BLOB read, measured in fractions of a millisecond. Immich ran the same
    /// comparison in a near-identical grid and found generating placeholders alongside
    /// thumbnails cost 2500 ms against 1550 ms -- a 61% penalty to mask a read that was
    /// already faster than a frame -- and removed theirs.
    ///
    /// So: one flat colour, no decode step, 2 MB across a 500,000-item library.
    public static func extract(from image: CGImage) -> Int? {
        // Averaging by drawing into a 1x1 context hands the work to Core Graphics' own
        // downsampler rather than walking pixels, which would mean reading the full bitmap
        // back into memory -- the exact thing this whole pipeline avoids.
        var pixel: [UInt8] = [0, 0, 0, 0]
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: &pixel,
                width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return nil }

        context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return (Int(pixel[0]) << 16) | (Int(pixel[1]) << 8) | Int(pixel[2])
    }

    /// Splits a packed colour back into components, for the SwiftUI side.
    public static func components(_ packed: Int) -> (red: Double, green: Double, blue: Double) {
        (
            Double((packed >> 16) & 0xFF) / 255,
            Double((packed >> 8) & 0xFF) / 255,
            Double(packed & 0xFF) / 255
        )
    }
}
