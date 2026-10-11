import Foundation
import QuickLookUI
import UniformTypeIdentifiers
import os

@objc(NikonPreviewProvider)
final class NikonPreviewProvider: QLPreviewProvider, QLPreviewingController {
    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let preview = try EmbeddedPreview.read(from: request.fileURL)
        Logger(subsystem: "local.alex.NikonFinderPreview", category: "preview").info("Providing embedded NEF preview")
        return QLPreviewReply(dataOfContentType: .jpeg, contentSize: preview.displaySize) { _ in
            try preview.orientedJPEG()
        }
    }
}
