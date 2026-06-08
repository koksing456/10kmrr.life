import Foundation

extension SetupModel {
    var hasLastGoodCache: Bool {
        !lastRefreshText.hasPrefix("No cached")
    }

    var canInstallOverlay: Bool {
        localSupport.sourceRootURL != nil && !isBusyWithLocalSupport && isConfigured && hasLastGoodCache
    }

    var canRepairOverlay: Bool {
        localSupport.sourceRootURL != nil && !isBusyWithLocalSupport
    }

    var installCommand: String {
        localSupport.command(scriptName: "install_lock_overlay_agent.sh")
    }

    var repairCommand: String {
        localSupport.command(scriptName: "repair_lock_overlay_agent.sh")
    }

    func copyInstallCommand() {
        copyToPasteboard(installCommand)
        supportText = "Copied direct install command."
    }

    func copyRepairCommand() {
        copyToPasteboard(repairCommand)
        supportText = "Copied repair command. Repair keeps Keychain, cache, and display settings."
    }

    func installOverlay() async {
        guard !isBusyWithLocalSupport else { return }
        guard let sourceRootURL = localSupport.sourceRootURL else {
            supportText = "Source checkout not detected. Copy the guided start command and run it from your checkout."
            return
        }
        guard isConfigured && hasLastGoodCache else {
            supportText = "Install needs a saved restricted key and a successful local MRR refresh first."
            return
        }

        isInstallingOverlay = true
        supportText = "Installing overlay LaunchAgent..."

        let output = await Self.runScript(named: "install_lock_overlay_agent.sh", in: sourceRootURL)
        if output.contains("LaunchAgent loaded"),
           output.contains("Installed overlay app"),
           output.contains("Installed LaunchAgent") {
            supportText = "Installed overlay LaunchAgent. Lock the Mac to verify visibility, then run Diagnose if anything looks wrong."
        } else {
            supportText = SetupLocalSupport.sanitizedDiagnosticSummary(from: output)
        }

        refreshStatus()
        refreshCacheStatus()
        isInstallingOverlay = false
    }

    func repairOverlay() async {
        guard !isBusyWithLocalSupport else { return }
        guard let sourceRootURL = localSupport.sourceRootURL else {
            supportText = "Source checkout not detected. Copy the repair command and run it from your checkout."
            return
        }

        isRepairingOverlay = true
        supportText = "Repairing app and LaunchAgent while preserving local data..."

        let output = await Self.runScript(named: "repair_lock_overlay_agent.sh", in: sourceRootURL)
        if output.contains("Repair keeps Keychain, cache, and display settings."),
           output.contains("LaunchAgent loaded") {
            supportText = "Repair finished and LaunchAgent loaded. Keychain, cache, and display settings were preserved."
        } else {
            supportText = SetupLocalSupport.sanitizedDiagnosticSummary(from: output)
        }

        refreshStatus()
        refreshCacheStatus()
        isRepairingOverlay = false
    }
}
