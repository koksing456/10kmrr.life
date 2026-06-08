import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor private var overlayController: LockScreenOverlayController?
    @MainActor private var setupWindow: NSWindow?
    @MainActor private var statusItem: NSStatusItem?

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
        installStatusMenu()
    }

    @MainActor
    private func showSetupWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 820),
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

    @MainActor
    private func installStatusMenu() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "chart.line.uptrend.xyaxis", accessibilityDescription: "10kmrr.life")
        item.button?.toolTip = "10kmrr.life"

        let menu = NSMenu()
        menu.addItem(menuItem("Open Setup...", action: #selector(openSetupFromMenu)))
        menu.addItem(menuItem("Refresh MRR Now", action: #selector(refreshMRRFromMenu)))
        menu.addItem(menuItem("Preview Overlay", action: #selector(previewOverlayFromMenu)))
        menu.addItem(.separator())
        menu.addItem(menuItem("Copy Diagnose Command", action: #selector(copyDiagnoseCommand)))
        menu.addItem(menuItem("Copy Support Report Command", action: #selector(copySupportReportCommand)))
        menu.addItem(menuItem("Copy Repair Command", action: #selector(copyRepairCommand)))
        menu.addItem(menuItem("Copy Uninstall Command", action: #selector(copyUninstallCommand)))
        menu.addItem(menuItem("Open Logs Folder", action: #selector(openLogsFolder)))
        menu.addItem(.separator())
        menu.addItem(menuItem("Restart Overlay", action: #selector(restartOverlayFromMenu)))
        item.menu = menu
        statusItem = item
    }

    @MainActor
    private func menuItem(_ title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc @MainActor
    private func openSetupFromMenu() {
        openNewAppInstance(arguments: ["--setup"])
    }

    @objc @MainActor
    private func refreshMRRFromMenu() {
        overlayController?.refreshNow()
    }

    @objc @MainActor
    private func previewOverlayFromMenu() {
        openNewAppInstance(arguments: ["--preview", "--private-glass"])
    }

    @objc @MainActor
    private func copyDiagnoseCommand() {
        copyToPasteboard(localSupportCommand(scriptName: "diagnose.sh"))
    }

    @objc @MainActor
    private func copySupportReportCommand() {
        copyToPasteboard(localSupportAlphaCommand(command: "support-report"))
    }

    @objc @MainActor
    private func copyRepairCommand() {
        copyToPasteboard(localSupportCommand(scriptName: "repair_lock_overlay_agent.sh"))
    }

    @objc @MainActor
    private func copyUninstallCommand() {
        copyToPasteboard(localSupportCommand(scriptName: "uninstall_lock_overlay_agent.sh", arguments: ["--all"]))
    }

    @objc @MainActor
    private func openLogsFolder() {
        let logsURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/10kmrr.life/logs")
        try? FileManager.default.createDirectory(at: logsURL, withIntermediateDirectories: true)
        NSWorkspace.shared.open(logsURL)
    }

    @objc @MainActor
    private func restartOverlayFromMenu() {
        NSApp.terminate(nil)
    }

    @MainActor
    private func openNewAppInstance(arguments: [String]) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.arguments = arguments
        configuration.activates = true
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, error in
            if let error {
                NSLog("%@: menu launch failed: %@", appSubsystem, error.localizedDescription)
            }
        }
    }

    @MainActor
    private func copyToPasteboard(_ command: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
    }

    @MainActor
    private func localSupportCommand(scriptName: String, arguments: [String] = []) -> String {
        SetupLocalSupport(bundleURL: Bundle.main.bundleURL).command(scriptName: scriptName, arguments: arguments)
    }

    @MainActor
    private func localSupportAlphaCommand(command: String, arguments: [String] = []) -> String {
        SetupLocalSupport(bundleURL: Bundle.main.bundleURL).alphaCommand(command: command, arguments: arguments)
    }
}
