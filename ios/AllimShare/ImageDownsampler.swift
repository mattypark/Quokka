import ImageIO
import UniformTypeIdentifiers
import CoreGraphics
import AVFoundation
import Foundation

/// Turns whatever the share sheet handed over into one small thumbnail, without ever
/// materialising the full bitmap.
///
/// This runs inside an app extension, which is killed at roughly 120 MB
/// (`EXC_RESOURCE RESOURCE_TYPE_MEMORY`). The canonical way to hit that limit is exactly this
/// workload -- decode a `UIImage` from a file, then make a second resized `UIImage` -- because
/// a decoded bitmap costs width x height x 4 bytes regardless of how small the compressed
/// file was. A 4000x3000 photo is ~48 MB decoded, twice over. ImageIO never decodes the full
/// image at all, so the ceiling is never approached.
enum ImageDownsampler {

    /// 800px on the long edge: a 400pt tile at 2x, which is the largest the grid ever shows.
    /// Storing more would multiply the library's footprint for pixels nothing renders.
    static let maxPixelSize = 800

    static func thumbnail(from data: Data) -> (data: Data, filename: String)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
        return encode(thumbnail(from: source))
    }

    static func thumbnail(fromFileAt url: URL) -> (data: Data, filename: String)? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else { return nil }
        return encode(thumbnail(from: source))
    }

    /// Computed, not stored: CFDictionary is not Sendable, so a shared static would be a
    /// concurrency error. Building it costs nothing next to reading the image.
    private static var sourceOptions: CFDictionary { [kCGImageSourceShouldCache: false] as CFDictionary }

    private static func thumbnail(from source: CGImageSource) -> CGImage? {
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
    /// footprint. It is safe here specifically because Allim is device-local -- the usual
    /// objection, that browsers cannot decode HEIC, does not apply to anything that will ever
    /// read these bytes. The capability is checked rather than assumed: `CGImageDestination`
    /// creation returns nil on hardware with no HEVC encoder.
    private static func encode(_ image: CGImage?) -> (data: Data, filename: String)? {
        guard let image else { return nil }
        let quality: CGFloat = 0.8

        let supportsHEIC = (CGImageDestinationCopyTypeIdentifiers() as? [String])?
            .contains(AVFileType.heic.rawValue) ?? false

        if supportsHEIC,
           let out = CFDataCreateMutable(nil, 0),
           let destination = CGImageDestinationCreateWithData(out, AVFileType.heic.rawValue as CFString, 1, nil) {
            CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
            if CGImageDestinationFinalize(destination) {
                return (out as Data, "\(UUID().uuidString).heic")
            }
        }

        guard let out = CFDataCreateMutable(nil, 0),
              let destination = CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return (out as Data, "\(UUID().uuidString).jpg")
    }
}
