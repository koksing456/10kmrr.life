import SwiftUI

extension MRRLockOverlayView {
    var heroContent: some View {
        ZStack {
            heroAtmosphere

            VStack(alignment: .center, spacing: 10) {
                HStack(spacing: 8) {
                    statusDot
                    Text(heroEyebrowText)
                        .font(.system(size: labelFontSize, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.76))
                        .lineLimit(1)
                }

                Capsule(style: .continuous)
                    .fill(heroHairlineStyle)
                    .frame(width: min(panelSize.width * 0.30, 96), height: 1)
                    .opacity(0.72)

                Text(model.primaryValue)
                    .font(.system(size: valueFontSize, weight: .medium, design: .rounded))
                    .foregroundStyle(heroValueStyle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.42)
                    .monospacedDigit()
                    .shadow(color: .black.opacity(0.38), radius: 24, x: 0, y: 14)

                Text(heroCaptionText)
                    .font(.system(size: footerFontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .monospacedDigit()
            }
            .padding(.horizontal, contentHorizontalPadding)
            .padding(.vertical, contentVerticalPadding)
        }
        .frame(width: panelSize.width, height: panelSize.height)
        .background(Color.white.opacity(usePrivateGlassComponent ? 0.00 : 0.035))
    }

    var heroAtmosphere: some View {
        ZStack {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.96, green: 1.00, blue: 0.98).opacity(0.16),
                            Color(red: 0.73, green: 0.91, blue: 1.00).opacity(0.06),
                            .black.opacity(0.16)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.20),
                            .white.opacity(0.02),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: panelSize.height * 0.42)
                .frame(maxHeight: .infinity, alignment: .top)
            heroLightBand
                .offset(x: -panelSize.width * 0.08, y: -panelSize.height * 0.04)
            heroLightBand
                .opacity(0.52)
                .offset(x: panelSize.width * 0.18, y: panelSize.height * 0.18)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .allowsHitTesting(false)
    }

    var heroLightBand: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        .clear,
                        .white.opacity(0.22),
                        .white.opacity(0.04),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: panelSize.width * 0.78, height: 18)
            .rotationEffect(.degrees(-18))
            .blur(radius: 6)
    }

    var heroHairlineStyle: LinearGradient {
        LinearGradient(
            colors: [
                .clear,
                .white.opacity(0.78),
                Color(red: 0.72, green: 0.96, blue: 0.88).opacity(0.72),
                .clear
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var heroValueStyle: LinearGradient {
        LinearGradient(
            colors: [
                .white.opacity(1.00),
                Color(red: 0.88, green: 1.00, blue: 0.95).opacity(0.96)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
