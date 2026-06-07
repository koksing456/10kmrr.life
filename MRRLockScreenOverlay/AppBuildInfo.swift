import Foundation

enum AppBuildInfo {
    static var version: String {
        stringValue(for: "CFBundleShortVersionString", fallback: "0.1.0")
    }

    static var build: String {
        stringValue(for: "CFBundleVersion", fallback: "1")
    }

    static var commit: String {
        stringValue(for: "TenKMRRCommit", fallback: "unknown")
    }

    static var displayText: String {
        "Version \(version) (\(commit))"
    }

    private static func stringValue(for key: String, fallback: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty
        else {
            return fallback
        }
        return value
    }
}
