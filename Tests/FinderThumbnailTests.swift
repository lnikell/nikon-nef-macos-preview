import Foundation
import QuickLookThumbnailing
import ImageIO

// Exercises macOS's installed provider, including the small sizes Finder uses.
@main
enum FinderThumbnailTests {
    static func main() throws {
        guard CommandLine.arguments.count >= 3 else {
            fatalError("Usage: FinderThumbnailTests output-directory image.NEF [image.NEF ...]")
        }
        let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        var passed = 0
        for path in CommandLine.arguments.dropFirst(2) {
            let url = URL(fileURLWithPath: path)
            let preview = try EmbeddedPreview.read(from: url)
            for (points, scale) in [(16.0, 2.0), (128.0, 2.0), (512.0, 1.0)] {
                let request = QLThumbnailGenerator.Request(fileAt: url,
                    size: CGSize(width: points, height: points), scale: scale,
                    representationTypes: .thumbnail)
                var done = false
                var failure: Error?
                var result: CGImage?
                QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, error in
                    DispatchQueue.main.async {
                        result = representation?.cgImage
                        failure = error
                        done = true
                    }
                }
                let deadline = Date().addingTimeInterval(20)
                while !done && Date() < deadline {
                    RunLoop.current.run(until: Date().addingTimeInterval(0.02))
                }
                guard done, failure == nil, let image = result else {
                    QLThumbnailGenerator.shared.cancel(request)
                    fatalError("Thumbnail failed: \(path): \(String(describing: failure))")
                }
                let factor = points * scale / max(preview.displaySize.width, preview.displaySize.height)
                guard abs(Double(image.width) - preview.displaySize.width * factor) <= 1,
                      abs(Double(image.height) - preview.displaySize.height * factor) <= 1 else {
                    fatalError("Incorrect dimensions/orientation: \(image.width)x\(image.height)")
                }
                if points == 512 {
                    let target = output.appendingPathComponent(url.lastPathComponent + ".png")
                    let destination = CGImageDestinationCreateWithURL(target as CFURL, "public.png" as CFString, 1, nil)!
                    CGImageDestinationAddImage(destination, image, nil)
                    guard CGImageDestinationFinalize(destination) else { fatalError("Could not save test output") }
                }
                print("PASS \(url.lastPathComponent): \(Int(points))pt @\(Int(scale))x -> \(image.width)x\(image.height)")
                passed += 1
            }
        }
        print("PASS: \(passed) system thumbnail requests")
    }
}
