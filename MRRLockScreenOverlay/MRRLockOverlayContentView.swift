import SwiftUI

extension MRRLockOverlayView {
    var focusContent: some View {
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

    var headerRow: some View {
        HStack(spacing: 9) {
            Text(headerText)
                .font(.system(size: labelFontSize, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.82))
            statusDot
            Spacer(minLength: 0)
        }
    }

    var valueText: some View {
        Text(model.primaryValue)
            .font(.system(size: valueFontSize, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.96))
            .lineLimit(1)
            .minimumScaleFactor(0.50)
            .monospacedDigit()
            .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 10)
    }

    var footerRow: some View {
        HStack(alignment: .center, spacing: 12) {
            timestampText
            Spacer(minLength: 0)
            if let footerStatusText {
                statusFooterText(footerStatusText)
            }
        }
    }

    var compactFooter: some View {
        HStack(spacing: 10) {
            timestampText
            if let footerStatusText {
                statusFooterText(footerStatusText)
            }
        }
    }

    var goalContent: some View {
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

    var timestampText: some View {
        Text(model.timestampText)
            .font(.system(size: footerFontSize, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.68))
            .lineLimit(1)
            .monospacedDigit()
    }

    func statusFooterText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: footerFontSize, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.64))
            .lineLimit(1)
    }
}
