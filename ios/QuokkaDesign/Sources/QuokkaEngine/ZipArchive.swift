import Compression
import Foundation

/// A read-only zip reader that inflates only the entries asked for.
///
/// **This exists so nobody has to unzip anything.** The import used to require expanding the
/// archive in Files first, which is a long-press on a context menu most people have never
/// opened, on a multi-gigabyte file, before the app is even involved. That step lost more
/// imports than every parsing bug combined.
///
/// Targeted rather than general on purpose. An Instagram export is overwhelmingly photos and
/// videos, and the importer wants a handful of JSON files -- so the central directory is read,
/// the wanted names are matched, and only those entries are decompressed. Extracting the whole
/// archive would mean writing gigabytes to disk to read a few megabytes of it.
///
/// No dependency: `Compression` is a system framework and is on macOS too, which keeps this
/// testable under `swift test` with no simulator.
public struct ZipArchive: Sendable {

    public struct Entry: Sendable, Equatable {
        public let path: String
        let method: UInt16
        let compressedSize: Int
        let uncompressedSize: Int
        let localHeaderOffset: Int

        public var name: String { (path as NSString).lastPathComponent }
    }

    public enum Failure: Error, Sendable, Equatable {
        case notAZip
        case unreadable
        case unsupportedCompression(UInt16)
        case corrupt(String)
    }

    private let handle: FileHandle
    public let entries: [Entry]

    /// Opens an archive and reads its central directory.
    ///
    /// A `FileHandle` rather than loading the file: these archives run to gigabytes and the
    /// whole point is to touch a few kilobytes of that.
    public init(url: URL) throws {
        guard let handle = try? FileHandle(forReadingFrom: url) else { throw Failure.unreadable }
        self.handle = handle
        do {
            self.entries = try Self.readCentralDirectory(handle)
        } catch {
            try? handle.close()
            throw error
        }
    }

    public func close() { try? handle.close() }

    /// The bytes of one entry, decompressed.
    public func data(for entry: Entry) throws -> Data {
        // The central directory records the name and extra-field lengths of the *central*
        // record, not the local one, and the two differ in practice. So the local header is
        // re-read to find where the data actually starts -- using the central lengths here is
        // the classic way to produce an archive that unzips everywhere except in your code.
        try handle.seek(toOffset: UInt64(entry.localHeaderOffset))
        guard let header = try handle.read(upToCount: 30), header.count == 30 else {
            throw Failure.corrupt("short local header")
        }
        guard header.u32(0) == 0x0403_4b50 else { throw Failure.corrupt("bad local signature") }
        let nameLength = Int(header.u16(26))
        let extraLength = Int(header.u16(28))

        try handle.seek(toOffset: UInt64(entry.localHeaderOffset + 30 + nameLength + extraLength))
        guard let payload = try handle.read(upToCount: entry.compressedSize),
              payload.count == entry.compressedSize
        else { throw Failure.corrupt("short entry payload") }

        switch entry.method {
        case 0:
            return payload
        case 8:
            return try Self.inflate(payload, expecting: entry.uncompressedSize)
        default:
            // Zip supports a dozen methods almost nothing emits. Named in the error rather than
            // swallowed, so an archive that fails says which method it wanted.
            throw Failure.unsupportedCompression(entry.method)
        }
    }

    /// Raw deflate, which is what zip stores -- no zlib header, so `COMPRESSION_ZLIB` here
    /// means raw deflate rather than the zlib wrapper the constant's name suggests.
    private static func inflate(_ data: Data, expecting size: Int) throws -> Data {
        guard size > 0 else { return Data() }
        var out = Data(count: size)
        let written: Int = out.withUnsafeMutableBytes { destination in
            data.withUnsafeBytes { source in
                compression_decode_buffer(
                    destination.bindMemory(to: UInt8.self).baseAddress!, size,
                    source.bindMemory(to: UInt8.self).baseAddress!, data.count,
                    nil, COMPRESSION_ZLIB)
            }
        }
        guard written > 0 else { throw Failure.corrupt("inflate produced nothing") }
        return out.prefix(written)
    }

    // MARK: - Central directory

    private static func readCentralDirectory(_ handle: FileHandle) throws -> [Entry] {
        let fileSize = Int(try handle.seekToEnd())
        // The end-of-central-directory record sits at the very end, after a comment of up to
        // 64 KB. Searched backwards over that window rather than assumed at a fixed offset.
        let window = min(fileSize, 65_536 + 22)
        try handle.seek(toOffset: UInt64(fileSize - window))
        guard let tail = try handle.read(upToCount: window) else { throw Failure.unreadable }

        guard let eocd = lastIndex(of: 0x0605_4b50, in: tail) else { throw Failure.notAZip }

        var count = Int(tail.u16(eocd + 10))
        var directoryOffset = Int(tail.u32(eocd + 16))

        // Zip64. A large export can exceed 65,535 entries or 4 GB, and the classic record then
        // stores sentinel 0xFFFF / 0xFFFFFFFF values. Reading those as real numbers seeks to
        // garbage and reports a corrupt archive for a file that is perfectly fine.
        if count == 0xFFFF || directoryOffset == 0xFFFF_FFFF {
            guard let locator = lastIndex(of: 0x0706_4b50, in: tail) else {
                throw Failure.corrupt("zip64 sentinel with no locator")
            }
            let zip64Offset = Int(tail.u64(locator + 8))
            try handle.seek(toOffset: UInt64(zip64Offset))
            guard let record = try handle.read(upToCount: 56), record.count == 56,
                  record.u32(0) == 0x0606_4b50
            else { throw Failure.corrupt("bad zip64 record") }
            count = Int(record.u64(32))
            directoryOffset = Int(record.u64(48))
        }

        try handle.seek(toOffset: UInt64(directoryOffset))
        guard let directory = try handle.read(upToCount: fileSize - directoryOffset) else {
            throw Failure.unreadable
        }

        var entries: [Entry] = []
        entries.reserveCapacity(count)
        var cursor = 0

        while entries.count < count, cursor + 46 <= directory.count {
            guard directory.u32(cursor) == 0x0201_4b50 else { break }
            let nameLength = Int(directory.u16(cursor + 28))
            let extraLength = Int(directory.u16(cursor + 30))
            let commentLength = Int(directory.u16(cursor + 32))
            let nameStart = cursor + 46
            guard nameStart + nameLength <= directory.count else { break }

            let path = String(
                decoding: directory[directory.startIndex + nameStart ..< directory.startIndex + nameStart + nameLength],
                as: UTF8.self)

            var compressed = Int(directory.u32(cursor + 20))
            var uncompressed = Int(directory.u32(cursor + 24))
            var localOffset = Int(directory.u32(cursor + 42))

            if compressed == 0xFFFF_FFFF || uncompressed == 0xFFFF_FFFF || localOffset == 0xFFFF_FFFF {
                readZip64Extra(
                    directory, at: nameStart + nameLength, length: extraLength,
                    uncompressed: &uncompressed, compressed: &compressed, localOffset: &localOffset)
            }

            // Directory markers are entries too, and inflating one yields nothing useful.
            if !path.hasSuffix("/") {
                entries.append(
                    Entry(
                        path: path,
                        method: directory.u16(cursor + 10),
                        compressedSize: compressed,
                        uncompressedSize: uncompressed,
                        localHeaderOffset: localOffset))
            }
            cursor = nameStart + nameLength + extraLength + commentLength
        }

        return entries
    }

    /// The Zip64 extended-information extra field, which carries the real sizes in the order
    /// they were sentinelled -- absent values are simply not present, so the fields cannot be
    /// read at fixed offsets.
    private static func readZip64Extra(
        _ data: Data, at start: Int, length: Int,
        uncompressed: inout Int, compressed: inout Int, localOffset: inout Int
    ) {
        var cursor = start
        let end = min(start + length, data.count)
        while cursor + 4 <= end {
            let id = data.u16(cursor)
            let size = Int(data.u16(cursor + 2))
            guard cursor + 4 + size <= end else { return }
            if id == 0x0001 {
                var field = cursor + 4
                if uncompressed == 0xFFFF_FFFF, field + 8 <= end { uncompressed = Int(data.u64(field)); field += 8 }
                if compressed == 0xFFFF_FFFF, field + 8 <= end { compressed = Int(data.u64(field)); field += 8 }
                if localOffset == 0xFFFF_FFFF, field + 8 <= end { localOffset = Int(data.u64(field)) }
                return
            }
            cursor += 4 + size
        }
    }

    private static func lastIndex(of signature: UInt32, in data: Data) -> Int? {
        guard data.count >= 4 else { return nil }
        var i = data.count - 4
        while i >= 0 {
            if data.u32(i) == signature { return i }
            i -= 1
        }
        return nil
    }
}

/// Little-endian reads at a byte offset, independent of where the `Data` slice starts.
///
/// The index arithmetic is the part that goes wrong: a `Data` produced by slicing does not
/// begin at 0, and using a bare integer subscript silently reads from the wrong place.
private extension Data {
    func u16(_ offset: Int) -> UInt16 {
        let i = startIndex + offset
        guard i + 1 < endIndex else { return 0 }
        return UInt16(self[i]) | UInt16(self[i + 1]) << 8
    }

    func u32(_ offset: Int) -> UInt32 {
        let i = startIndex + offset
        guard i + 3 < endIndex else { return 0 }
        return (0..<4).reduce(UInt32(0)) { $0 | UInt32(self[i + $1]) << (8 * UInt32($1)) }
    }

    func u64(_ offset: Int) -> UInt64 {
        let i = startIndex + offset
        guard i + 7 < endIndex else { return 0 }
        return (0..<8).reduce(UInt64(0)) { $0 | UInt64(self[i + $1]) << (8 * UInt64($1)) }
    }
}
