import Foundation

private enum TestFailure: Error, CustomStringConvertible {
    case mismatch(String)
    case missing(String)

    var description: String {
        switch self {
        case let .mismatch(message):
            return message
        case let .missing(message):
            return message
        }
    }
}

@main
private enum SetupLocalSupportTests {
    static func main() {
        do {
            try testSourceRootDetection()
            try testSourceRootMarkerFallback()
            try testCommandGeneration()
            try testShellQuoting()
            try testSupportReportPathAndRedaction()
            try testDiagnosticSummarySanitizesSensitiveValues()
            print("Setup local support tests passed (6 cases).")
        } catch {
            fputs("\(error)\n", stderr)
            exit(1)
        }
    }

    private static func testSourceRootMarkerFallback() throws {
        let tempRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("10kmrr-marker-support-\(UUID().uuidString)")
        defer {
            try? FileManager.default.removeItem(at: tempRoot)
        }

        let sourceRoot = tempRoot.appendingPathComponent("source checkout")
        try makeValidSourceRoot(sourceRoot)

        let installedAppURL = tempRoot
            .appendingPathComponent("Installed/MRRLockScreenOverlay.app")
        try FileManager.default.createDirectory(at: installedAppURL, withIntermediateDirectories: true)

        let appSupportURL = tempRoot.appendingPathComponent("Application Support/10kmrr.life")
        try FileManager.default.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
        try "\(sourceRoot.path)\n".write(
            to: SetupLocalSupport.sourceRootMarkerURL(appSupportURL: appSupportURL),
            atomically: true,
            encoding: .utf8
        )

        let support = SetupLocalSupport(bundleURL: installedAppURL, appSupportURL: appSupportURL)
        try assertEqual(support.sourceRootURL?.path, sourceRoot.path, "source marker fallback")
        try assertEqual(
            support.command(scriptName: "diagnose.sh"),
            "cd '\(sourceRoot.path)' && ./script/diagnose.sh",
            "installed app command should use source marker"
        )
    }

    private static func testSourceRootDetection() throws {
        let tempRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("10kmrr-setup-support-\(UUID().uuidString)")
        defer {
            try? FileManager.default.removeItem(at: tempRoot)
        }

        let appURL = tempRoot
            .appendingPathComponent("build/LockScreenOverlay/MRRLockScreenOverlay.app")
        try FileManager.default.createDirectory(
            at: appURL,
            withIntermediateDirectories: true
        )
        try makeValidSourceRoot(tempRoot)

        let detectedRoot = SetupLocalSupport.detectSourceRoot(from: appURL)
        try assertEqual(detectedRoot?.path, tempRoot.path, "source root detection")
    }

    private static func makeValidSourceRoot(_ sourceRoot: URL) throws {
        try FileManager.default.createDirectory(
            at: sourceRoot.appendingPathComponent("script"),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: sourceRoot.appendingPathComponent("MRRLockScreenOverlay"),
            withIntermediateDirectories: true
        )
        let diagnoseURL = sourceRoot.appendingPathComponent("script/diagnose.sh")
        try "#!/usr/bin/env bash\n".write(to: diagnoseURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: diagnoseURL.path)
        try "".write(
            to: sourceRoot.appendingPathComponent("MRRLockScreenOverlay/SetupWindowView.swift"),
            atomically: true,
            encoding: .utf8
        )
    }

    private static func testCommandGeneration() throws {
        let support = SetupLocalSupport(sourceRootURL: URL(fileURLWithPath: "/tmp/10kmrr test"))
        try assertEqual(
            support.command(scriptName: "diagnose.sh"),
            "cd '/tmp/10kmrr test' && ./script/diagnose.sh",
            "command should include quoted checkout path"
        )
        try assertEqual(
            support.command(scriptName: "support_report.sh", arguments: ["--include-logs"]),
            "cd '/tmp/10kmrr test' && ./script/support_report.sh --include-logs",
            "command should include arguments"
        )
        try assertEqual(
            support.alphaCommand(command: "support-report", arguments: ["--note", "needs review"]),
            "cd '/tmp/10kmrr test' && ./script/alpha.sh support-report --note 'needs review'",
            "alpha command should use the unified alpha entrypoint and quote arguments"
        )
    }

    private static func testShellQuoting() throws {
        try assertEqual(
            SetupLocalSupport.shellQuotedPath("/tmp/kok's app"),
            "'/tmp/kok'\\''s app'",
            "single quote shell escaping"
        )
        try assertEqual(
            SetupLocalSupport.shellQuotedToken("plain-token"),
            "plain-token",
            "plain shell token"
        )
        try assertEqual(
            SetupLocalSupport.shellQuotedToken("value with spaces"),
            "'value with spaces'",
            "space shell token escaping"
        )
    }

    private static func testSupportReportPathAndRedaction() throws {
        let sourceRootURL = URL(fileURLWithPath: "/Users/example/10kmrr.life")
        let support = SetupLocalSupport(sourceRootURL: sourceRootURL)

        try assertEqual(
            support.supportReportURL?.path,
            "/Users/example/10kmrr.life/build/support/10kmrr-support-report.txt",
            "support report path"
        )
        try assertEqual(
            SetupLocalSupport.redactedLocalPath(
                "/Users/example/10kmrr.life/build/support/10kmrr-support-report.txt",
                homeDirectory: "/Users/example",
                sourceRootURL: sourceRootURL
            ),
            "<repo>/build/support/10kmrr-support-report.txt",
            "support report display path"
        )
    }

    private static func testDiagnosticSummarySanitizesSensitiveValues() throws {
        let restrictedLivePrefix = "rk_" + "live_"
        let rawOutput = """
        10kmrr.life local diagnostic
        Home: /Users/example
        PASS  Last-good MRR cache exists. Cached value was not printed.
        WARN  Stripe key \(restrictedLivePrefix)1234567890abcdef should never be shown.
        WARN  Stripe customer cus_1234567890abcdef should never be shown.
        WARN  Stripe field customer_email should never be shown.
        WARN  Email founder@example.com should never be shown.
        WARN  Demo amount US$12,345.67 should not be shown.
        WARN  Demo amount $351.93 should not be shown.
        WARN  MRR 10248.00 should not be shown.
        Suggested next steps:
          - Generate sanitized support report: ./script/support_report.sh
        """

        let summary = SetupLocalSupport.sanitizedDiagnosticSummary(
            from: rawOutput,
            homeDirectory: "/Users/example"
        )

        try assertContains(summary, "PASS  Last-good MRR cache exists", "status line")
        try assertContains(summary, "WARN  Stripe key \(restrictedLivePrefix)[redacted]", "secret redaction")
        try assertContains(summary, "WARN  Stripe customer [redacted Stripe object]", "Stripe object redaction")
        try assertContains(summary, "WARN  Stripe field [redacted Stripe field]", "Stripe field redaction")
        try assertContains(summary, "WARN  Email [redacted email]", "email redaction")
        try assertContains(summary, "WARN  Demo amount [redacted amount]", "amount redaction")
        try assertContains(summary, "  - Generate sanitized support report", "next action")
        try assertNotContains(summary, "/Users/example", "home path redaction")
        try assertNotContains(summary, "1234567890abcdef", "secret suffix redaction")
        try assertNotContains(summary, "cus_1234567890abcdef", "Stripe object id redaction")
        try assertNotContains(summary, "customer_email", "Stripe field redaction")
        try assertNotContains(summary, "founder@example.com", "email redaction")
        try assertNotContains(summary, "12,345.67", "amount value redaction")
        try assertNotContains(summary, "351.93", "bare dollar amount redaction")
        try assertNotContains(summary, "10248.00", "MRR-labelled amount redaction")
    }

    private static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) throws {
        guard actual == expected else {
            throw TestFailure.mismatch("\(message). Expected \(expected), got \(actual).")
        }
    }

    private static func assertContains(_ value: String, _ substring: String, _ message: String) throws {
        guard value.contains(substring) else {
            throw TestFailure.missing("\(message). Expected to find \(substring) in \(value).")
        }
    }

    private static func assertNotContains(_ value: String, _ substring: String, _ message: String) throws {
        guard !value.contains(substring) else {
            throw TestFailure.mismatch("\(message). Did not expect to find \(substring) in \(value).")
        }
    }
}
