import Foundation
import QuickLookThumbnailing
import os

@objc(NikonThumbnailProvider)
final class NikonThumbnailProvider: QLThumbnailProvider {
    override func provideThumbnail(for request: QLFileThumbnailRequest, _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {
        do {
            let preview = try EmbeddedPreview.read(from: request.fileURL)
            let pixels = Int(ceil(max(request.maximumSize.width, request.maximumSize.height) * request.scale))
            let image = try preview.thumbnail(maxPixelSize: pixels)
            let factor = min(request.maximumSize.width / CGFloat(image.width), request.maximumSize.height / CGFloat(image.height))
            let size = CGSize(width: CGFloat(image.width) * factor, height: CGFloat(image.height) * factor)
            Logger(subsystem: "local.alex.NikonFinderPreview", category: "thumbnail").info("Providing embedded NEF thumbnail")
            let reply = QLThumbnailReply(contextSize: size) { context in
                Self.drawThumbnail(image, in: context)
            }
            handler(reply, nil)
        } catch {
            handler(nil, error)
        }
    }

    static func drawThumbnail(_ image: CGImage, in context: CGContext) -> Bool {
        // Quick Look scales the bitmap dimensions for Retina displays. The
        // Core Graphics callback can still have an identity transform, so a
        // rectangle measured in points would paint only its bottom-left quarter.
        // Convert the complete bitmap from device space to the actual user space.
        let pixels = CGRect(x: 0, y: 0, width: context.width, height: context.height)
        let bounds = context.convertToUserSpace(pixels)
        context.interpolationQuality = .high
        context.draw(image, in: bounds)
        return true
    }
}
