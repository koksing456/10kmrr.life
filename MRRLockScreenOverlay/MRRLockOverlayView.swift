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

    private var panelContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 9) {
                Text("Stripe MRR")
                    .font(.system(size: labelFontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.82))
                statusDot
                Spacer(minLength: 0)
            }

            Text(model.primaryValue)
                .font(.system(size: valueFontSize, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.96))
                .lineLimit(1)
                .minimumScaleFactor(0.50)
                .monospacedDigit()
                .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 10)

            HStack(alignment: .center, spacing: 12) {
                Text(model.timestampText)
                    .font(.system(size: footerFontSize, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.68))
                    .monospacedDigit()
                Spacer(minLength: 0)
                if let footerStatusText {
                    Text(footerStatusText)
                        .font(.system(size: footerFontSize, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.64))
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 22)
        .frame(width: panelSize.width, height: panelSize.height)
        .background(Color.white.opacity(usePrivateGlassComponent ? 0.00 : 0.035))
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

    private var footerStatusText: String? {
        if model.errorText != nil, model.result != nil { return "Cached" }
        if model.errorText != nil { return "Needs attention" }
        if model.isRefreshing { return "Refreshing" }
        return nil
    }
}
