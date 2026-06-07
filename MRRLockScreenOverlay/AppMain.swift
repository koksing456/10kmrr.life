import AppKit

@main
private enum MRRLockScreenOverlayApplication {
    private static let delegate = AppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.delegate = delegate
        app.run()
    }
}
