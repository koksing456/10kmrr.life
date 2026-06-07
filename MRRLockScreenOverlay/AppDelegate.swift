import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor private var overlayController: LockScreenOverlayController?
    @MainActor private var setupWindow: NSWindow?

    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        let previewMode = CommandLine.arguments.contains("--preview")
        NSApp.setActivationPolicy(previewMode || setupMode ? .regular : .accessory)
        if previewMode || setupMode {
            NSApp.activate(ignoringOtherApps: true)
        }

        if setupMode {
            showSetupWindow()
            return
        }

        let controller = LockScreenOverlayController()
        overlayController = controller
        controller.start(previewMode: previewMode)
    }

    @MainActor
    private func showSetupWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 520),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "10kmrr.life Setup"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: SetupWindowView())
        window.makeKeyAndOrderFront(nil)
        setupWindow = window
    }
}
