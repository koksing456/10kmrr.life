import AppKit
import Foundation

enum OverlaySettingsStore {
    private static let defaults = UserDefaults(suiteName: "life.10kmrr.MRRLockScreenOverlay.Settings") ?? .standard
    private static let refreshIntervalKey = "refreshIntervalSeconds"
    private static let placementKey = "placement"
    private static let horizontalPlacementKey = "horizontalPlacement"
    private static let sizePresetKey = "sizePreset"
    private static let displayModeKey = "displayMode"
    private static let visualStyleKey = "visualStyle"
    private static let goalCurrencyKey = "goalCurrency"
    private static let goalMinorUnitsKey = "goalMinorUnits"

    static var refreshIntervalSeconds: TimeInterval {
        let stored = defaults.integer(forKey: refreshIntervalKey)
        guard stored >= 60 else { return 300 }
        return TimeInterval(stored)
    }

    static var refreshIntervalMinutes: Int {
        get { Int(refreshIntervalSeconds / 60) }
        set {
            let bounded = max(1, min(newValue, 60))
            defaults.set(bounded * 60, forKey: refreshIntervalKey)
        }
    }

    static var placement: OverlayPlacement {
        get { enumValue(forKey: placementKey, fallback: .center) }
        set { defaults.set(newValue.rawValue, forKey: placementKey) }
    }

    static var horizontalPlacement: OverlayHorizontalPlacement {
        get { enumValue(forKey: horizontalPlacementKey, fallback: .center) }
        set { defaults.set(newValue.rawValue, forKey: horizontalPlacementKey) }
    }

    static var sizePreset: OverlaySizePreset {
        get { enumValue(forKey: sizePresetKey, fallback: .medium) }
        set { defaults.set(newValue.rawValue, forKey: sizePresetKey) }
    }

    static var displayMode: OverlayDisplayMode {
        get { enumValue(forKey: displayModeKey, fallback: .main) }
        set { defaults.set(newValue.rawValue, forKey: displayModeKey) }
    }

    static var visualStyle: OverlayVisualStyle {
        get { enumValue(forKey: visualStyleKey, fallback: .hero) }
        set { defaults.set(newValue.rawValue, forKey: visualStyleKey) }
    }

    static var goalCurrency: String {
        get {
            let stored = defaults.string(forKey: goalCurrencyKey) ?? "usd"
            let cleaned = stored.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return cleaned.isEmpty ? "usd" : cleaned
        }
        set {
            let cleaned = newValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            defaults.set(cleaned.isEmpty ? "usd" : cleaned, forKey: goalCurrencyKey)
        }
    }

    static var goalMinorUnits: Int64? {
        get {
            guard let value = defaults.object(forKey: goalMinorUnitsKey) as? NSNumber else { return nil }
            let minorUnits = value.int64Value
            return minorUnits > 0 ? minorUnits : nil
        }
        set {
            if let newValue, newValue > 0 {
                defaults.set(NSNumber(value: newValue), forKey: goalMinorUnitsKey)
            } else {
                defaults.removeObject(forKey: goalMinorUnitsKey)
            }
        }
    }

    static var panelSize: NSSize {
        let baseSize = sizePreset.size
        switch visualStyle {
        case .hero:
            return NSSize(width: baseSize.width + 24, height: baseSize.height + 10)
        case .full, .goal, .focus:
            return baseSize
        case .compact:
            return NSSize(width: max(330, baseSize.width - 58), height: max(118, baseSize.height - 44))
        case .number:
            return NSSize(width: max(292, baseSize.width - 112), height: max(92, baseSize.height - 76))
        }
    }

    static func reset() {
        [
            refreshIntervalKey,
            placementKey,
            horizontalPlacementKey,
            sizePresetKey,
            displayModeKey,
            visualStyleKey,
            goalCurrencyKey,
            goalMinorUnitsKey
        ].forEach(defaults.removeObject)
    }

    private static func enumValue<T: RawRepresentable>(forKey key: String, fallback: T) -> T where T.RawValue == String {
        guard let rawValue = defaults.string(forKey: key),
              let value = T(rawValue: rawValue)
        else {
            return fallback
        }
        return value
    }
}
