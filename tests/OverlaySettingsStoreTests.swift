import AppKit
import Foundation

private enum TestFailure: Error, CustomStringConvertible {
    case mismatch(String)

    var description: String {
        switch self {
        case let .mismatch(message):
            return message
        }
    }
}

@main
private enum OverlaySettingsStoreTests {
    private static let suiteName = "life.10kmrr.MRRLockScreenOverlay.Settings.Tests.\(getpid())"

    static func main() {
        do {
            setenv("TENKMRR_SETTINGS_SUITE", suiteName, 1)
            cleanup()
            defer { cleanup() }

            try testDefaults()
            try testRefreshIntervalBounds()
            try testEnumPersistenceAndFallbacks()
            try testGoalNormalization()
            try testPanelSizes()

            print("Overlay settings tests passed (5 cases).")
        } catch {
            fputs("\(error)\n", stderr)
            cleanup()
            exit(1)
        }
    }

    private static func testDefaults() throws {
        OverlaySettingsStore.reset()
        try assertEqual(OverlaySettingsStore.refreshIntervalSeconds, 300, "default refresh interval")
        try assertEqual(OverlaySettingsStore.refreshIntervalMinutes, 5, "default refresh minutes")
        try assertEqual(OverlaySettingsStore.placement, .center, "default vertical placement")
        try assertEqual(OverlaySettingsStore.horizontalPlacement, .center, "default horizontal placement")
        try assertEqual(OverlaySettingsStore.sizePreset, .medium, "default size preset")
        try assertEqual(OverlaySettingsStore.displayMode, .main, "default display mode")
        try assertEqual(OverlaySettingsStore.visualStyle, .hero, "default visual style")
        try assertEqual(OverlaySettingsStore.goalCurrency, "usd", "default goal currency")
        try assertEqual(OverlaySettingsStore.goalMinorUnits, nil, "default goal minor units")
    }

    private static func testRefreshIntervalBounds() throws {
        OverlaySettingsStore.refreshIntervalMinutes = 0
        try assertEqual(OverlaySettingsStore.refreshIntervalSeconds, 60, "minimum refresh interval")

        OverlaySettingsStore.refreshIntervalMinutes = 90
        try assertEqual(OverlaySettingsStore.refreshIntervalSeconds, 3600, "maximum refresh interval")
    }

    private static func testEnumPersistenceAndFallbacks() throws {
        OverlaySettingsStore.placement = .high
        OverlaySettingsStore.horizontalPlacement = .right
        OverlaySettingsStore.sizePreset = .large
        OverlaySettingsStore.displayMode = .all
        OverlaySettingsStore.visualStyle = .focus

        try assertEqual(OverlaySettingsStore.placement, .high, "stored vertical placement")
        try assertEqual(OverlaySettingsStore.horizontalPlacement, .right, "stored horizontal placement")
        try assertEqual(OverlaySettingsStore.sizePreset, .large, "stored size preset")
        try assertEqual(OverlaySettingsStore.displayMode, .all, "stored display mode")
        try assertEqual(OverlaySettingsStore.visualStyle, .focus, "stored visual style")

        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set("bad-placement", forKey: "placement")
        defaults.set("bad-horizontal", forKey: "horizontalPlacement")
        defaults.set("bad-size", forKey: "sizePreset")
        defaults.set("bad-display", forKey: "displayMode")
        defaults.set("bad-style", forKey: "visualStyle")

        try assertEqual(OverlaySettingsStore.placement, .center, "invalid vertical placement fallback")
        try assertEqual(OverlaySettingsStore.horizontalPlacement, .center, "invalid horizontal placement fallback")
        try assertEqual(OverlaySettingsStore.sizePreset, .medium, "invalid size preset fallback")
        try assertEqual(OverlaySettingsStore.displayMode, .main, "invalid display mode fallback")
        try assertEqual(OverlaySettingsStore.visualStyle, .hero, "invalid visual style fallback")
    }

    private static func testGoalNormalization() throws {
        OverlaySettingsStore.goalCurrency = " GBP \n"
        OverlaySettingsStore.goalMinorUnits = 123_456
        try assertEqual(OverlaySettingsStore.goalCurrency, "gbp", "goal currency should normalize")
        try assertEqual(OverlaySettingsStore.goalMinorUnits, 123_456, "goal minor units should persist")

        OverlaySettingsStore.goalCurrency = "   "
        OverlaySettingsStore.goalMinorUnits = 0
        try assertEqual(OverlaySettingsStore.goalCurrency, "usd", "empty goal currency should fall back")
        try assertEqual(OverlaySettingsStore.goalMinorUnits, nil, "zero goal should clear")

        OverlaySettingsStore.goalMinorUnits = -100
        try assertEqual(OverlaySettingsStore.goalMinorUnits, nil, "negative goal should clear")
    }

    private static func testPanelSizes() throws {
        OverlaySettingsStore.sizePreset = .medium
        OverlaySettingsStore.visualStyle = .hero
        try assertEqual(OverlaySettingsStore.panelSize, NSSize(width: 456, height: 186), "hero panel size")

        OverlaySettingsStore.visualStyle = .compact
        try assertEqual(OverlaySettingsStore.panelSize, NSSize(width: 374, height: 132), "compact panel size")

        OverlaySettingsStore.visualStyle = .number
        try assertEqual(OverlaySettingsStore.panelSize, NSSize(width: 320, height: 100), "number panel size")
    }

    private static func cleanup() {
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
    }

    private static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) throws {
        guard actual == expected else {
            throw TestFailure.mismatch("\(message). Expected \(expected), got \(actual).")
        }
    }
}
