import Foundation
import CoreGraphics
import ImageIO

@main
enum ThumbnailDrawingTests {
    static func bitmap(width: Int, height: Int) -> CGContext {
        CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                  bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)!
    }

    static func coveredCorners(_ context: CGContext) -> Int {
        let data = context.data!.assumingMemoryBound(to: UInt8.self)
        var covered = 0
        for (x, y) in [(1, 1), (context.width - 2, 1), (1, context.height - 2), (context.width - 2, context.height - 2)] {
            let pixel = y * context.bytesPerRow + x * 4
            if data[pixel] > 200 && data[pixel + 1] < 60 && data[pixel + 2] < 60 && data[pixel + 3] == 255 {
                covered += 1
            }
        }
        return covered
    }

    static func main() throws {
        let source = bitmap(width: 24, height: 36)
        source.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        source.fill(CGRect(x: 0, y: 0, width: 24, height: 36))
        let image = source.makeImage()!

        // Reproduce the reported bug: a 2x bitmap with an identity transform,
        // filled using the requested point dimensions, paints only one quarter.
        let legacy = bitmap(width: 24, height: 36)
        legacy.setFillColor(CGColor(gray: 1, alpha: 1))
        legacy.fill(CGRect(x: 0, y: 0, width: 24, height: 36))
        legacy.draw(image, in: CGRect(x: 0, y: 0, width: 12, height: 18))
        precondition(coveredCorners(legacy) == 1, "The regression fixture must reproduce the old bottom-left-only drawing")

        var checks = 0
        for size in [CGSize(width: 12, height: 18), CGSize(width: 18, height: 12)] {
            for scale in [1, 2, 3] {
                for usesPointTransform in [false, true] {
                    let context = bitmap(width: Int(size.width) * scale, height: Int(size.height) * scale)
                    context.setFillColor(CGColor(gray: 1, alpha: 1))
                    context.fill(CGRect(x: 0, y: 0, width: context.width, height: context.height))
                    if usesPointTransform { context.scaleBy(x: CGFloat(scale), y: CGFloat(scale)) }
                    precondition(NikonThumbnailProvider.drawThumbnail(image, in: context))
                    precondition(coveredCorners(context) == 4,
                                 "Image must fill the thumbnail at \(scale)x, point transform: \(usesPointTransform)")
                    checks += 1
                }
            }
        }
        print("PASS: old Retina bug reproduced; \(checks) full-canvas drawing checks passed")
    }
}
