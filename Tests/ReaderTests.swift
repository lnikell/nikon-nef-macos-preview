import Foundation
import ImageIO
import CoreGraphics

@main
enum ReaderTests {
    static var checks = 0
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fatalError("FAIL: \(message)") }
        checks += 1
    }

    static func write(_ number: UInt32, bytes: Int, at offset: Int, into data: inout Data, little: Bool) {
        for i in 0..<bytes {
            data[offset + i] = UInt8((number >> ((little ? i : bytes - i - 1) * 8)) & 255)
        }
    }

    static func fixture(jpeg: Data, orientation: Int, little: Bool, cyclic: Bool = false) -> Data {
        var data = Data(repeating: 0, count: 64)
        data[0] = little ? 0x49 : 0x4d; data[1] = data[0]
        write(42, bytes: 2, at: 2, into: &data, little: little)
        write(8, bytes: 4, at: 4, into: &data, little: little)
        write(3, bytes: 2, at: 8, into: &data, little: little)
        for (index, field) in [(0x0112, 3, orientation), (0x0201, 4, 64), (0x0202, 4, jpeg.count)].enumerated() {
            let offset = 10 + index * 12
            write(UInt32(field.0), bytes: 2, at: offset, into: &data, little: little)
            write(UInt32(field.1), bytes: 2, at: offset + 2, into: &data, little: little)
            write(1, bytes: 4, at: offset + 4, into: &data, little: little)
            write(UInt32(field.2), bytes: field.1 == 3 ? 2 : 4, at: offset + 8, into: &data, little: little)
        }
        if cyclic { write(8, bytes: 4, at: 46, into: &data, little: little) }
        data.append(jpeg)
        return data
    }

    static func expectFailure(_ data: Data, _ label: String) {
        do { _ = try EmbeddedPreview.read(data: data); fatalError("FAIL: accepted \(label)") }
        catch { checks += 1 }
    }

    static func syntheticJPEG(width: Int = 96, height: Int = 64) -> Data {
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(red: 0.8, green: 0.15, blue: 0.2, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(CGColor(red: 0.1, green: 0.3, blue: 0.9, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height / 2))
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, "public.jpeg" as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        precondition(CGImageDestinationFinalize(destination))
        return data as Data
    }

    static func main() throws {
        guard CommandLine.arguments.count == 2 else { fatalError("Usage: ReaderTests output-directory") }
        let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let preview = try EmbeddedPreview.read(data: fixture(jpeg: syntheticJPEG(), orientation: 8, little: true))
        check(preview.pixelWidth == 96 && preview.pixelHeight == 64, "read JPEG dimensions")
        check(preview.orientation == 8, "read portrait orientation")
        let oriented = try preview.orientedJPEG()
        try oriented.write(to: output.appendingPathComponent("oriented-preview.jpg"))
        let image = try preview.thumbnail(maxPixelSize: 60)
        check(image.width == 40 && image.height == 60, "portrait thumbnail dimensions")
        let destination = CGImageDestinationCreateWithURL(output.appendingPathComponent("thumbnail.png") as CFURL, "public.png" as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image, nil)
        check(CGImageDestinationFinalize(destination), "save thumbnail")

        for little in [true, false] {
            for orientation in 1...8 {
                let test = try EmbeddedPreview.read(data: fixture(jpeg: preview.jpeg, orientation: orientation, little: little))
                check(test.jpeg == preview.jpeg, "preserve original compressed JPEG bytes")
                check(test.orientation == orientation, "read orientation \(orientation)")
                let thumbnail = try test.thumbnail(maxPixelSize: 60)
                check(thumbnail.width == (orientation >= 5 ? 40 : 60), "oriented width")
                check(thumbnail.height == (orientation >= 5 ? 60 : 40), "oriented height")
                let rewritten = try test.orientedJPEG()
                let source = CGImageSourceCreateWithData(rewritten as CFData, nil)!
                let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)! as NSDictionary
                check(props[kCGImagePropertyOrientation] as? Int == orientation, "write JPEG orientation")
            }
        }
        let cyclic = try EmbeddedPreview.read(data: fixture(jpeg: preview.jpeg, orientation: 1, little: true, cyclic: true))
        check(cyclic.pixelWidth == 96, "bound cyclic directory traversal")
        // A small primary JPEG plus a larger SubIFD preview mirrors Nikon NEFs.
        var multiple = fixture(jpeg: syntheticJPEG(width: 24, height: 16), orientation: 8, little: true)
        let subdirectory = multiple.count
        let larger = fixture(jpeg: preview.jpeg, orientation: 1, little: true)
        multiple.append(larger.dropFirst(8))
        write(4, bytes: 2, at: 8, into: &multiple, little: true)
        write(0x014a, bytes: 2, at: 46, into: &multiple, little: true)
        write(4, bytes: 2, at: 48, into: &multiple, little: true)
        write(1, bytes: 4, at: 50, into: &multiple, little: true)
        write(UInt32(subdirectory), bytes: 4, at: 54, into: &multiple, little: true)
        write(0, bytes: 4, at: 58, into: &multiple, little: true)
        write(UInt32(subdirectory + 56), bytes: 4, at: subdirectory + 22, into: &multiple, little: true)
        let selected = try EmbeddedPreview.read(data: multiple)
        check(selected.jpeg == preview.jpeg, "choose largest SubIFD preview")
        check(selected.orientation == 8, "keep primary orientation for SubIFD JPEG")
        expectFailure(Data(), "empty file")
        expectFailure(Data("not a TIFF".utf8), "non-TIFF")
        expectFailure(fixture(jpeg: preview.jpeg, orientation: 1, little: true).prefix(40), "truncated directory")
        var broken = fixture(jpeg: preview.jpeg, orientation: 1, little: true)
        write(UInt32.max, bytes: 4, at: 30, into: &broken, little: true)
        expectFailure(broken, "out-of-bounds JPEG")
        expectFailure(fixture(jpeg: Data([0, 1, 2, 3]), orientation: 1, little: true), "invalid JPEG")
        print("PASS: \(checks) reader checks; JPEG \(preview.pixelWidth)x\(preview.pixelHeight), orientation \(preview.orientation)")
    }
}
