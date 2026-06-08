import Foundation

struct SetupLocalSupport {
    let sourceRootURL: URL?

    init(bundleURL: URL = Bundle.main.bundleURL, appSupportURL: URL = Self.defaultAppSupportURL()) {
        sourceRootURL = Self.detectSourceRoot(from: bundleURL)
            ?? Self.detectSourceRootFromMarker(appSupportURL: appSupportURL)
    }

    init(sourceRootURL: URL?) {
        self.sourceRootURL = sourceRootURL
    }

    var sourceStatusText: String {
        if let sourceRootURL {
            return "Source checkout detected at \(Self.redactedHomePath(sourceRootURL.path))"
        }
        return "Source checkout not detected from this app bundle. Copy commands and run them from your 10kmrr.life checkout."
    }

    var supportReportURL: URL? {
        sourceRootURL?.appendingPathComponent("build/support/10kmrr-support-report.txt")
    }

    func command(scriptName: String, arguments: [String] = []) -> String {
        scriptCommand(tokens: ["./script/\(scriptName)"] + arguments)
    }

    func alphaCommand(command: String, arguments: [String] = []) -> String {
        scriptCommand(tokens: ["./script/alpha.sh", command] + arguments)
    }

    private func scriptCommand(tokens: [String]) -> String {
        let baseCommand = tokens.map(Self.shellQuotedToken).joined(separator: " ")
        guard let sourceRootURL else {
            return baseCommand
        }
        return "cd \(Self.shellQuotedPath(sourceRootURL.path)) && \(baseCommand)"
    }

    static func detectSourceRoot(from bundleURL: URL) -> URL? {
        var currentURL = bundleURL.deletingLastPathComponent()

        for _ in 0..<8 {
            if isValidSourceRoot(currentURL) {
                return currentURL
            }
            currentURL.deleteLastPathComponent()
        }

        return nil
    }

    static func detectSourceRootFromMarker(appSupportURL: URL) -> URL? {
        let markerURL = sourceRootMarkerURL(appSupportURL: appSupportURL)
        guard let rawPath = try? String(contentsOf: markerURL, encoding: .utf8) else {
            return nil
        }
        let path = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return nil }

        let sourceRootURL = URL(fileURLWithPath: path)
        return isValidSourceRoot(sourceRootURL) ? sourceRootURL : nil
    }

    static func sourceRootMarkerURL(appSupportURL: URL) -> URL {
        appSupportURL.appendingPathComponent("source-checkout.path")
    }

    static func defaultAppSupportURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/10kmrr.life")
    }

    private static func isValidSourceRoot(_ sourceRootURL: URL) -> Bool {
        let fileManager = FileManager.default
        let diagnosePath = sourceRootURL.appendingPathComponent("script/diagnose.sh").path
        let sourcePath = sourceRootURL.appendingPathComponent("MRRLockScreenOverlay/SetupWindowView.swift").path
        return fileManager.isExecutableFile(atPath: diagnosePath) &&
            fileManager.fileExists(atPath: sourcePath)
    }

    static func shellQuotedPath(_ path: String) -> String {
        "'\(path.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    static func shellQuotedToken(_ token: String) -> String {
        guard token.rangeOfCharacter(from: CharacterSet.whitespacesAndNewlines) != nil ||
              token.contains("'") ||
              token.contains("\"") ||
              token.contains("$") ||
              token.contains("\\")
        else {
            return token
        }
        return shellQuotedPath(token)
    }

    static func redactedHomePath(_ path: String, homeDirectory: String = NSHomeDirectory()) -> String {
        path.replacingOccurrences(of: homeDirectory, with: "~")
    }

    static func redactedLocalPath(
        _ path: String,
        homeDirectory: String = NSHomeDirectory(),
        sourceRootURL: URL?
    ) -> String {
        var redacted = path
        if let sourceRootURL {
            redacted = redacted.replacingOccurrences(of: sourceRootURL.path, with: "<repo>")
        }
        redacted = redacted.replacingOccurrences(of: homeDirectory, with: "~")
        return redacted
    }

    static func sanitizedDiagnosticSummary(
        from output: String,
        homeDirectory: String = NSHomeDirectory(),
        maxLines: Int = 12
    ) -> String {
        let safeOutput = output
            .replacingOccurrences(of: homeDirectory, with: "~")
            .replacingOccurrences(
                of: "(sk_live_|sk_test_|rk_live_|rk_test_|whsec_)[A-Za-z0-9_\\-]+",
                with: "$1[redacted]",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: "([A-Z]{2,4}\\$[0-9][0-9,]*(\\.[0-9]{2})?|[A-Z]{3}[[:space:]]+[0-9][0-9,]*(\\.[0-9]{2})?)",
                with: "[redacted amount]",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: "\\$[0-9][0-9,]*(\\.[0-9]{2})?",
                with: "[redacted amount]",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: "(?i)\\b(MRR|ARR|revenue|amount)\\s*[:=]?\\s*[0-9][0-9,]*(\\.[0-9]{2})?",
                with: "[redacted amount]",
                options: .regularExpression
            )

        let usefulPrefixes = ["PASS  ", "WARN  ", "FAIL  ", "ERROR ", "NEXT  ", "RULE  ", "Suggested next steps:", "  - "]
        let summaryLines = safeOutput
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { line in
                usefulPrefixes.contains { line.hasPrefix($0) }
            }
            .prefix(maxLines)

        if summaryLines.isEmpty {
            return "Diagnostic finished without status lines."
        }

        return summaryLines.joined(separator: "\n")
    }
}
