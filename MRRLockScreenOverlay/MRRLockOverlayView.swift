import SwiftUI

struct MRRLockOverlayView: View {
    @ObservedObject var model: MRRDisplayModel
    @State private var pulse = false

    private let cornerRadius: CGFloat = 34
    private var panelSize: NSSize {
        OverlaySettingsStore.panelSize
    }
    private var sizePreset: OverlaySizePreset {
        OverlaySettingsStore.sizePreset
    }
    private var visualStyle: OverlayVisualStyle {
        OverlaySettingsStore.visualStyle
    }
    private var contentSpacing: CGFloat {
        switch visualStyle {
        case .full, .goal:
            return 18
        case .compact:
            return 12
        case .number:
            return 6
        case .focus:
            return 10
        }
    }

    @ViewBuilder
    var body: some View {
        Group {
            if usePrivateGlassComponent {
                PrivateGlassBackground(variant: 11, cornerRadius: cornerRadius) {
                    panelContent
                }
                .frame(width: panelSize.width, height: panelSize.height)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            } else {
                panelContent
                    .background(stableFrostedBackground)
                    .frame(width: panelSize.width, height: panelSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
        }
        .overlay(panelEdgeTreatment)
        .environment(\.colorScheme, .dark)
        .shadow(color: .black.opacity(0.24), radius: 34, x: 0, y: 22)
        .onAppear {
            pulse = true
        }
    }

    @ViewBuilder
    private var panelContent: some View {
        if visualStyle == .focus {
            focusContent
        } else {
            VStack(alignment: .leading, spacing: contentSpacing) {
                if visualStyle != .number {
                    headerRow
                }

                valueText

                switch visualStyle {
                case .goal:
                    goalContent
                case .full:
                    footerRow
                case .compact:
                    compactFooter
                case .number, .focus:
                    EmptyView()
                }
            }
            .padding(.horizontal, contentHorizontalPadding)
            .padding(.vertical, contentVerticalPadding)
            .frame(width: panelSize.width, height: panelSize.height)
            .background(Color.white.opacity(usePrivateGlassComponent ? 0.00 : 0.035))
        }
    }

    private var focusContent: some View {
        VStack(alignment: .center, spacing: 11) {
            HStack(spacing: 8) {
                statusDot
                Text(headerText)
                    .font(.system(size: labelFontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.74))
                    .lineLimit(1)
            }

            Text(model.primaryValue)
                .font(.system(size: valueFontSize, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.98))
                .lineLimit(1)
                .minimumScaleFactor(0.46)
                .monospacedDigit()
                .shadow(color: .black.opacity(0.32), radius: 20, x: 0, y: 12)

            Text(focusCaptionText)
                .font(.system(size: footerFontSize, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.64))
                .lineLimit(1)
                .monospacedDigit()
        }
        .padding(.horizontal, contentHorizontalPadding)
        .padding(.vertical, contentVerticalPadding)
        .frame(width: panelSize.width, height: panelSize.height)
        .background(Color.white.opacity(usePrivateGlassComponent ? 0.00 : 0.035))
    }

    private var headerRow: some View {
        HStack(spacing: 9) {
            Text(headerText)
                .font(.system(size: labelFontSize, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.82))
            statusDot
            Spacer(minLength: 0)
        }
    }

    private var valueText: some View {
        Text(model.primaryValue)
            .font(.system(size: valueFontSize, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.96))
            .lineLimit(1)
            .minimumScaleFactor(0.50)
            .monospacedDigit()
            .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 10)
    }

    private var footerRow: some View {
        HStack(alignment: .center, spacing: 12) {
            timestampText
            Spacer(minLength: 0)
            if let footerStatusText {
                statusFooterText(footerStatusText)
            }
        }
    }

    private var compactFooter: some View {
        HStack(spacing: 10) {
            timestampText
            if let footerStatusText {
                statusFooterText(footerStatusText)
            }
        }
    }

    private var goalContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(goalSummaryText)
                    .font(.system(size: footerFontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if let footerStatusText {
                    statusFooterText(footerStatusText)
                }
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.13))
                    Capsule()
                        .fill(goalProgressGradient)
                        .frame(width: max(8, proxy.size.width * goalProgress))
                }
            }
            .frame(height: 8)
        }
    }

    private var timestampText: some View {
        Text(model.timestampText)
            .font(.system(size: footerFontSize, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.68))
            .lineLimit(1)
            .monospacedDigit()
    }

    private func statusFooterText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: footerFontSize, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.64))
            .lineLimit(1)
    }

    private var stableFrostedBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.12),
                            .white.opacity(0.02),
                            .black.opacity(0.10)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
    }

    private var panelEdgeTreatment: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        .white.opacity(0.70),
                        .white.opacity(0.18),
                        .white.opacity(0.34)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1.25
            )
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.20), .white.opacity(0.00)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .bottom) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.black.opacity(0.00), .black.opacity(0.14)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 86)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .allowsHitTesting(false)
            }
    }

    private var statusDot: some View {
        ZStack {
            Circle()
                .fill(dotColor.opacity(0.20))
                .frame(width: 18, height: 18)
                .scaleEffect(pulse ? 1.18 : 0.82)
                .opacity(pulse ? 0.55 : 0.90)
            Circle()
                .fill(dotColor)
                .frame(width: 7.5, height: 7.5)
        }
        .shadow(color: dotColor.opacity(0.42), radius: 7)
        .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: pulse)
    }

    private var labelFontSize: CGFloat {
        if visualStyle == .number { return 0 }
        if visualStyle == .focus { return 14 }
        switch sizePreset {
        case .small:
            return 13
        case .medium:
            return 15
        case .large:
            return 16
        }
    }

    private var valueFontSize: CGFloat {
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

    private var footerFontSize: CGFloat {
        if visualStyle == .compact || visualStyle == .number || visualStyle == .focus {
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

    private var dotColor: Color {
        if model.isRefreshing { return .yellow }
        if model.errorText != nil { return .orange }
        return .green
    }

    private var contentHorizontalPadding: CGFloat {
        switch visualStyle {
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

    private var contentVerticalPadding: CGFloat {
        switch visualStyle {
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

    private var goalCurrency: String {
        OverlaySettingsStore.goalCurrency
    }

    private var goalMinorUnits: Int64? {
        OverlaySettingsStore.goalMinorUnits
    }

    private var goalCurrentMinorUnits: Int64 {
        model.amountMinorUnits(for: goalCurrency) ?? 0
    }

    private var goalProgress: CGFloat {
        guard let goalMinorUnits, goalMinorUnits > 0 else { return 0 }
        return min(1, max(0, CGFloat(Double(goalCurrentMinorUnits) / Double(goalMinorUnits))))
    }

    private var goalSummaryText: String {
        guard let goalMinorUnits else {
            return "Set a goal in setup"
        }
        let remaining = max(0, goalMinorUnits - goalCurrentMinorUnits)
        if remaining == 0 {
            return "Goal reached"
        }
        return "\(model.displayValue(minorUnits: remaining, currency: goalCurrency)) to goal"
    }

    private var goalProgressGradient: LinearGradient {
        LinearGradient(
            colors: [.white.opacity(0.92), Color(red: 0.56, green: 0.89, blue: 0.76).opacity(0.92)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var headerText: String {
        if model.isRefreshing { return "Refreshing Stripe" }
        if model.errorText != nil { return model.statusText }
        if model.statusText == "Mock" { return "Mock Stripe MRR" }
        if model.statusText == "Cached" { return "Stripe MRR cached" }
        return "Stripe MRR"
    }

    private var footerStatusText: String? {
        if model.statusText == "Mock" { return "Mock preview" }
        if model.errorText != nil, model.result != nil { return "Using cached MRR" }
        if model.errorText != nil { return model.statusText }
        if model.isRefreshing { return "Refreshing" }
        return nil
    }

    private var focusCaptionText: String {
        footerStatusText ?? model.timestampText
    }
}
