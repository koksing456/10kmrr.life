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

enum OverlaySettingsStore {
    private static let defaults = UserDefaults(suiteName: "life.10kmrr.MRRLockScreenOverlay.Settings") ?? .standard
    private static let refreshIntervalKey = "refreshIntervalSeconds"
    private static let placementKey = "placement"

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

    static func reset() {
        defaults.removeObject(forKey: refreshIntervalKey)
        defaults.removeObject(forKey: placementKey)
    }
}
