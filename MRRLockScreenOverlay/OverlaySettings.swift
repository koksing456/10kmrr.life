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

enum OverlaySettingsStore {
    private static let defaults = UserDefaults(suiteName: "life.10kmrr.MRRLockScreenOverlay.Settings") ?? .standard
    private static let refreshIntervalKey = "refreshIntervalSeconds"
    private static let placementKey = "placement"
    private static let horizontalPlacementKey = "horizontalPlacement"
    private static let sizePresetKey = "sizePreset"

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

    static var panelSize: NSSize {
        sizePreset.size
    }

    static func reset() {
        defaults.removeObject(forKey: refreshIntervalKey)
        defaults.removeObject(forKey: placementKey)
        defaults.removeObject(forKey: horizontalPlacementKey)
        defaults.removeObject(forKey: sizePresetKey)
    }
}
