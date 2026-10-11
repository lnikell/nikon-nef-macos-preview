import AppKit

// macOS registers the two embedded app extensions. There is no viewer or resident process.
@main
enum Container {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
    }
}
