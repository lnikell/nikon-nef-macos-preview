import Foundation
import ImageIO

enum PreviewError: LocalizedError {
    case invalidTIFF, invalidOffset, noJPEG, invalidJPEG
    var errorDescription: String? {
        switch self {
        case .invalidTIFF: return "This file is not a supported Nikon NEF."
        case .invalidOffset: return "The NEF contains an invalid image offset."
        case .noJPEG: return "This NEF does not contain a usable JPEG preview."
        case .invalidJPEG: return "The embedded JPEG could not be read."
        }
    }
}

struct EmbeddedPreview {
    let jpeg: Data
    let orientation: Int
    let pixelWidth: Int
    let pixelHeight: Int

    var displaySize: CGSize {
        orientation >= 5
            ? CGSize(width: pixelHeight, height: pixelWidth)
            : CGSize(width: pixelWidth, height: pixelHeight)
    }

    static func read(from url: URL) throws -> EmbeddedPreview {
        // Prefer memory mapping so directory and JPEG reads need not load the RAW payload.
        let data = try Data(contentsOf: url, options: [.mappedIfSafe, .uncached])
        return try read(data: data)
    }

    static func read(data: Data) throws -> EmbeddedPreview {
        var reader = try TIFFPreviewReader(data: data)
        return try reader.extract()
    }

    /// Copies compressed JPEG pixels and its colour profile, changing orientation metadata only.
    func orientedJPEG() throws -> Data {
        guard let source = CGImageSourceCreateWithData(jpeg as CFData, nil) else {
            throw PreviewError.invalidJPEG
        }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, "public.jpeg" as CFString, 1, nil) else {
            throw PreviewError.invalidJPEG
        }
        let options = [kCGImageDestinationOrientation: orientation] as CFDictionary
        var error: Unmanaged<CFError>?
        guard CGImageDestinationCopyImageSource(destination, source, options, &error) else {
            if let error { throw error.takeRetainedValue() as Error }
            throw PreviewError.invalidJPEG
        }
        return output as Data
    }

    func thumbnail(maxPixelSize: Int) throws -> CGImage {
        let data = try orientedJPEG()
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: max(1, min(maxPixelSize, 8192)),
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { throw PreviewError.invalidJPEG }
        return image
    }
}

private struct TIFFPreviewReader {
    private let data: Data
    private let littleEndian: Bool
    private var visited = Set<Int>()
    private var candidates: [(offset: Int, length: Int)] = []
    private var orientation = 1
    private static let maximumJPEGBytes = 128 * 1024 * 1024

    init(data: Data) throws {
        guard data.count >= 8 else { throw PreviewError.invalidTIFF }
        self.data = data
        if data[0] == 0x49 && data[1] == 0x49 { littleEndian = true }
        else if data[0] == 0x4d && data[1] == 0x4d { littleEndian = false }
        else { throw PreviewError.invalidTIFF }
        guard try uint16(at: 2) == 42 else { throw PreviewError.invalidTIFF }
    }

    mutating func extract() throws -> EmbeddedPreview {
        try visit(Int(uint32(at: 4)), primary: true)
        // Larger JPEGs normally correspond to Nikon's full-resolution JpgFromRaw.
        // Validate every candidate's dimensions and select the largest pixel area.
        var best: EmbeddedPreview?
        for candidate in candidates.sorted(by: { $0.length > $1.length }) {
            let jpeg = data.subdata(in: candidate.offset..<(candidate.offset + candidate.length))
            guard jpeg.count >= 4, jpeg[0] == 0xff, jpeg[1] == 0xd8,
                  let source = CGImageSourceCreateWithData(jpeg as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
                  CGImageSourceGetType(source) as String? == "public.jpeg",
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let width = properties[kCGImagePropertyPixelWidth] as? Int,
                  let height = properties[kCGImagePropertyPixelHeight] as? Int,
                  width > 0, height > 0, width <= 65535, height <= 65535,
                  width * height <= 200_000_000 else { continue }
            if best == nil || width * height > best!.pixelWidth * best!.pixelHeight {
                best = EmbeddedPreview(jpeg: jpeg, orientation: orientation, pixelWidth: width, pixelHeight: height)
            }
        }
        guard let best else { throw PreviewError.noJPEG }
        return best
    }

    private mutating func visit(_ offset: Int, primary: Bool = false) throws {
        guard offset != 0, !visited.contains(offset), visited.count < 64 else { return }
        visited.insert(offset)
        let count = Int(try uint16(at: offset))
        guard count <= 4096 else { throw PreviewError.invalidTIFF }
        try check(offset + 2, count * 12 + 4)
        var fields: [UInt16: [UInt32]] = [:]
        for index in 0..<count {
            let entry = offset + 2 + index * 12
            let tag = try uint16(at: entry)
            guard [0x0103, 0x0111, 0x0112, 0x0117, 0x014a, 0x0201, 0x0202].contains(tag) else { continue }
            fields[tag] = try values(at: entry)
        }
        if primary, let value = fields[0x0112]?.first, (1...8).contains(value) {
            orientation = Int(value)
        }
        if let start = fields[0x0201]?.first, let length = fields[0x0202]?.first {
            addCandidate(offset: Int(start), length: Int(length))
        }
        if let compression = fields[0x0103]?.first, compression == 6 || compression == 7,
           let offsets = fields[0x0111], offsets.count == 1,
           let lengths = fields[0x0117], lengths.count == 1 {
            addCandidate(offset: Int(offsets[0]), length: Int(lengths[0]))
        }
        for subdirectory in fields[0x014a] ?? [] {
            // Ignore broken optional directories if another valid preview exists.
            try? visit(Int(subdirectory))
        }
        let next = Int(try uint32(at: offset + 2 + count * 12))
        if next != 0 { try? visit(next) }
    }

    private mutating func addCandidate(offset: Int, length: Int) {
        guard offset >= 8, length >= 4, length <= Self.maximumJPEGBytes,
              offset <= data.count, length <= data.count - offset,
              !candidates.contains(where: { $0.offset == offset && $0.length == length }) else { return }
        candidates.append((offset, length))
    }

    private func values(at entry: Int) throws -> [UInt32] {
        let type = try uint16(at: entry + 2)
        let count = Int(try uint32(at: entry + 4))
        guard count <= 256 else { throw PreviewError.invalidTIFF }
        let width: Int
        switch type {
        case 3: width = 2
        case 4, 13: width = 4
        default: return []
        }
        let start = count * width <= 4 ? entry + 8 : Int(try uint32(at: entry + 8))
        try check(start, count * width)
        return try (0..<count).map { index in
            width == 2 ? UInt32(try uint16(at: start + index * width)) : try uint32(at: start + index * width)
        }
    }

    private func check(_ offset: Int, _ length: Int) throws {
        guard offset >= 0, length >= 0, offset <= data.count, length <= data.count - offset else {
            throw PreviewError.invalidOffset
        }
    }

    private func uint16(at offset: Int) throws -> UInt16 {
        try check(offset, 2)
        let first = UInt16(data[offset]), second = UInt16(data[offset + 1])
        return littleEndian ? first | second << 8 : first << 8 | second
    }

    private func uint32(at offset: Int) throws -> UInt32 {
        try check(offset, 4)
        var value: UInt32 = 0
        for index in 0..<4 {
            let shift = littleEndian ? index * 8 : (3 - index) * 8
            value |= UInt32(data[offset + index]) << shift
        }
        return value
    }
}
