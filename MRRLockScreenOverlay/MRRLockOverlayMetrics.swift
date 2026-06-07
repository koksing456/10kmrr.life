import SwiftUI

extension MRRLockOverlayView {
    var labelFontSize: CGFloat {
        if visualStyle == .number { return 0 }
        if visualStyle == .focus || visualStyle == .hero { return 14 }
        switch sizePreset {
        case .small:
            return 13
        case .medium:
            return 15
        case .large:
            return 16
        }
    }

    var valueFontSize: CGFloat {
        if visualStyle == .hero {
            switch sizePreset {
            case .small:
                return 50
            case .medium:
                return 62
            case .large:
                return 70
            }
        }
        if visualStyle == .focus {
            switch sizePreset {
            case .small:
                return 46
            case .medium:
                return 55
            case .large:
                return 64
            }
        }
        if visualStyle == .number {
            switch sizePreset {
            case .small:
                return 43
            case .medium:
                return 50
            case .large:
                return 56
            }
        }
        if visualStyle == .compact {
            switch sizePreset {
            case .small:
                return 38
            case .medium:
                return 46
            case .large:
                return 52
            }
        }
        switch sizePreset {
        case .small:
            return 44
        case .medium:
            return 54
        case .large:
            return 60
        }
    }

    var footerFontSize: CGFloat {
        if visualStyle == .compact || visualStyle == .number || visualStyle == .focus || visualStyle == .hero {
            return 11
        }
        switch sizePreset {
        case .small:
            return 12
        case .medium:
            return 13
        case .large:
            return 14
        }
    }

    var dotColor: Color {
        if model.isRefreshing { return .yellow }
        if model.errorText != nil { return .orange }
        return .green
    }

    var contentHorizontalPadding: CGFloat {
        switch visualStyle {
        case .hero:
            return 28
        case .full, .goal:
            return 24
        case .compact:
            return 22
        case .number:
            return 20
        case .focus:
            return 24
        }
    }

    var contentVerticalPadding: CGFloat {
        switch visualStyle {
        case .hero:
            return 20
        case .full, .goal:
            return 22
        case .compact:
            return 18
        case .number:
            return 16
        case .focus:
            return 20
        }
    }

    var goalCurrency: String {
        OverlaySettingsStore.goalCurrency
    }

    var goalMinorUnits: Int64? {
        OverlaySettingsStore.goalMinorUnits
    }

    var goalCurrentMinorUnits: Int64 {
        model.amountMinorUnits(for: goalCurrency) ?? 0
    }

    var goalProgress: CGFloat {
        guard let goalMinorUnits, goalMinorUnits > 0 else { return 0 }
        return min(1, max(0, CGFloat(Double(goalCurrentMinorUnits) / Double(goalMinorUnits))))
    }

    var goalSummaryText: String {
        guard let goalMinorUnits else {
            return "Set a goal in setup"
        }
        let remaining = max(0, goalMinorUnits - goalCurrentMinorUnits)
        if remaining == 0 {
            return "Goal reached"
        }
        return "\(model.displayValue(minorUnits: remaining, currency: goalCurrency)) to goal"
    }

    var goalProgressGradient: LinearGradient {
        LinearGradient(
            colors: [.white.opacity(0.92), Color(red: 0.56, green: 0.89, blue: 0.76).opacity(0.92)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var headerText: String {
        if model.isRefreshing { return "Refreshing Stripe" }
        if model.errorText != nil { return model.statusText }
        if model.statusText == "Mock" { return "Mock Stripe MRR" }
        if model.statusText == "Cached" { return "Stripe MRR cached" }
        return "Stripe MRR"
    }

    var heroEyebrowText: String {
        if model.isRefreshing { return "Syncing Stripe MRR" }
        if model.errorText != nil { return model.result == nil ? model.statusText : "Cached Stripe MRR" }
        if model.statusText == "Mock" { return "Mock Stripe MRR" }
        if model.statusText == "Cached" { return "Cached Stripe MRR" }
        return "Stripe MRR"
    }

    var heroCaptionText: String {
        if model.statusText == "Mock" { return "Mock preview" }
        if model.errorText != nil, model.result != nil { return "Cached - \(model.timestampText)" }
        if let footerStatusText { return footerStatusText }
        return model.timestampText
    }

    var footerStatusText: String? {
        if model.statusText == "Mock" { return "Mock preview" }
        if model.errorText != nil, model.result != nil { return "Using cached MRR" }
        if model.errorText != nil { return model.statusText }
        if model.isRefreshing { return "Refreshing" }
        return nil
    }

    var focusCaptionText: String {
        footerStatusText ?? model.timestampText
    }
}
