import AppKit
import Foundation

extension SetupModel {
    var canRunDiagnostic: Bool {
        localSupport.sourceRootURL != nil && !isRunningDiagnostic && !isGeneratingSupportReport
    }

    var canGenerateSupportReport: Bool {
        localSupport.sourceRootURL != nil && !isRunningDiagnostic && !isGeneratingSupportReport
    }

    var startCommand: String {
        localSupport.alphaCommand(command: "start")
    }

    var supportReportCommand: String {
        localSupport.alphaCommand(command: "support-report")
    }

    var diagnoseCommand: String {
        localSupport.command(scriptName: "diagnose.sh")
    }

    var repairCommand: String {
        localSupport.command(scriptName: "repair_lock_overlay_agent.sh")
    }

    func copyStartCommand() {
        copyToPasteboard(startCommand)
        supportText = "Copied guided alpha start command."
    }

    func copySupportReportCommand() {
        copyToPasteboard(supportReportCommand)
        supportText = "Copied sanitized support report command."
    }

    func copyDiagnoseCommand() {
        copyToPasteboard(diagnoseCommand)
        supportText = "Copied diagnose command."
    }

    func copyRepairCommand() {
        copyToPasteboard(repairCommand)
        supportText = "Copied repair command. Repair keeps Keychain, cache, and display settings."
    }

    func openLogsFolder() {
        let logsURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/10kmrr.life/logs")
        try? FileManager.default.createDirectory(at: logsURL, withIntermediateDirectories: true)
        NSWorkspace.shared.open(logsURL)
        supportText = "Opened local logs folder."
    }

    func openSupportReport() {
        guard let reportURL = localSupport.supportReportURL else {
            supportText = "Source checkout not detected. Generate the support report from your checkout first."
            return
        }

        if FileManager.default.fileExists(atPath: reportURL.path) {
            NSWorkspace.shared.open(reportURL)
            supportText = "Opened sanitized support report."
        } else {
            supportText = "No support report exists yet. Click Generate Report first."
        }
    }

    func runDiagnostic() async {
        guard !isRunningDiagnostic else { return }
        guard let sourceRootURL = localSupport.sourceRootURL else {
            supportText = "Source checkout not detected. Copy the diagnose command and run it from your checkout."
            return
        }

        isRunningDiagnostic = true
        supportText = "Running local diagnostic..."

        let output = await Self.runScript(named: "diagnose.sh", in: sourceRootURL)
        supportText = SetupLocalSupport.sanitizedDiagnosticSummary(from: output)
        refreshStatus()
        refreshCacheStatus()
        isRunningDiagnostic = false
    }

    func generateSupportReport() async {
        guard !isGeneratingSupportReport else { return }
        guard let sourceRootURL = localSupport.sourceRootURL else {
            supportText = "Source checkout not detected. Copy the support report command and run it from your checkout."
            return
        }

        isGeneratingSupportReport = true
        supportText = "Generating sanitized support report..."

        let output = await Self.runCommand(arguments: ["./script/alpha.sh", "support-report"], in: sourceRootURL)
        if let reportURL = localSupport.supportReportURL,
           FileManager.default.fileExists(atPath: reportURL.path) {
            let safePath = SetupLocalSupport.redactedLocalPath(
                reportURL.path,
                sourceRootURL: sourceRootURL
            )
            supportText = "Generated sanitized support report:\n\(safePath)\nReview before sharing."
            NSWorkspace.shared.open(reportURL)
        } else {
            supportText = SetupLocalSupport.sanitizedDiagnosticSummary(from: output)
        }

        refreshStatus()
        refreshCacheStatus()
        isGeneratingSupportReport = false
    }

    private func copyToPasteboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    private static func runScript(named scriptName: String, in sourceRootURL: URL) async -> String {
        await runCommand(arguments: ["./script/\(scriptName)"], in: sourceRootURL)
    }

    private static func runCommand(arguments: [String], in sourceRootURL: URL) async -> String {
        await Task.detached(priority: .userInitiated) {
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            let commandLabel = arguments.joined(separator: " ")

            process.currentDirectoryURL = sourceRootURL
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["-lc", commandLabel]
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                return "FAIL  Could not run \(commandLabel): \(error.localizedDescription)"
            }

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""
            let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

            if process.terminationStatus == 0 {
                return output
            }

            return output + "\nWARN  \(commandLabel) exited with status \(process.terminationStatus)\n" + errorOutput
        }.value
    }
}
