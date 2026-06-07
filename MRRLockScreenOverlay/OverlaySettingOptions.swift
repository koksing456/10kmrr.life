import AppKit

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
    case hero
    case full
    case compact
    case number
    case goal
    case focus

    var id: String { rawValue }

    var label: String {
        switch self {
        case .hero:
            return "Hero"
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
