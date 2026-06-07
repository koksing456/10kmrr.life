import AppKit
import Foundation

enum OverlayPlacement: String, CaseIterable, Identifiable {
    case high
    case center
    case low

    var id: String { rawValue }

    var label: String {
        switch self {
        case .high:
            return "Higher"
        case .center:
            return "Center"
        case .low:
            return "Lower"
        }
    }
}

enum OverlayHorizontalPlacement: String, CaseIterable, Identifiable {
    case left
    case center
    case right

    var id: String { rawValue }

    var label: String {
        switch self {
        case .left:
            return "Left"
        case .center:
            return "Center"
        case .right:
            return "Right"
        }
    }
}

enum OverlaySizePreset: String, CaseIterable, Identifiable {
    case small
    case medium
    case large

    var id: String { rawValue }

    var label: String {
        switch self {
        case .small:
            return "Small"
        case .medium:
            return "Default"
        case .large:
            return "Large"
        }
    }

    var size: NSSize {
        switch self {
        case .small:
            return NSSize(width: 372, height: 156)
        case .medium:
            return NSSize(width: 432, height: 176)
        case .large:
            return NSSize(width: 500, height: 198)
        }
    }
}

enum OverlayDisplayMode: String, CaseIterable, Identifiable {
    case main
    case cursor
    case all

    var id: String { rawValue }

    var label: String {
        switch self {
        case .main:
            return "Main"
        case .cursor:
            return "Cursor"
        case .all:
            return "All"
        }
    }
}

enum OverlayVisualStyle: String, CaseIterable, Identifiable {
    case full
    case compact
    case number
    case goal
    case focus

    var id: String { rawValue }

    var label: String {
        switch self {
        case .full:
            return "Full"
        case .compact:
            return "Compact"
        case .number:
            return "Number"
        case .goal:
            return "Goal"
        case .focus:
            return "Focus"
        }
    }
}

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
        get {
            guard let rawValue = defaults.string(forKey: placementKey),
                  let placement = OverlayPlacement(rawValue: rawValue)
            else {
                return .center
            }
            return placement
        }
        set {
            defaults.set(newValue.rawValue, forKey: placementKey)
        }
    }

    static var horizontalPlacement: OverlayHorizontalPlacement {
        get {
            guard let rawValue = defaults.string(forKey: horizontalPlacementKey),
                  let placement = OverlayHorizontalPlacement(rawValue: rawValue)
            else {
                return .center
            }
            return placement
        }
        set {
            defaults.set(newValue.rawValue, forKey: horizontalPlacementKey)
        }
    }

    static var sizePreset: OverlaySizePreset {
        get {
            guard let rawValue = defaults.string(forKey: sizePresetKey),
                  let sizePreset = OverlaySizePreset(rawValue: rawValue)
            else {
                return .medium
            }
            return sizePreset
        }
        set {
            defaults.set(newValue.rawValue, forKey: sizePresetKey)
        }
    }

    static var displayMode: OverlayDisplayMode {
        get {
            guard let rawValue = defaults.string(forKey: displayModeKey),
                  let displayMode = OverlayDisplayMode(rawValue: rawValue)
            else {
                return .main
            }
            return displayMode
        }
        set {
            defaults.set(newValue.rawValue, forKey: displayModeKey)
        }
    }

    static var visualStyle: OverlayVisualStyle {
        get {
            guard let rawValue = defaults.string(forKey: visualStyleKey),
                  let visualStyle = OverlayVisualStyle(rawValue: rawValue)
            else {
                return .full
            }
            return visualStyle
        }
        set {
            defaults.set(newValue.rawValue, forKey: visualStyleKey)
        }
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
        case .full, .goal, .focus:
            return baseSize
        case .compact:
            return NSSize(width: max(330, baseSize.width - 58), height: max(118, baseSize.height - 44))
        case .number:
            return NSSize(width: max(292, baseSize.width - 112), height: max(92, baseSize.height - 76))
        }
    }

    static func reset() {
        defaults.removeObject(forKey: refreshIntervalKey)
        defaults.removeObject(forKey: placementKey)
        defaults.removeObject(forKey: horizontalPlacementKey)
        defaults.removeObject(forKey: sizePresetKey)
        defaults.removeObject(forKey: displayModeKey)
        defaults.removeObject(forKey: visualStyleKey)
        defaults.removeObject(forKey: goalCurrencyKey)
        defaults.removeObject(forKey: goalMinorUnitsKey)
    }
}
