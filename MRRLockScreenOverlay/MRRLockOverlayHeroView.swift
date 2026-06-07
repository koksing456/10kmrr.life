import SwiftUI

extension MRRLockOverlayView {
    var heroContent: some View {
        ZStack {
            heroAtmosphere

            VStack(alignment: .center, spacing: 12) {
                HStack(spacing: 8) {
                    statusDot
                    Text(heroEyebrowText)
                        .font(.system(size: labelFontSize, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.76))
                        .lineLimit(1)
                }

                Text(model.primaryValue)
                    .font(.system(size: valueFontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(heroValueStyle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.42)
                    .monospacedDigit()
                    .shadow(color: .black.opacity(0.36), radius: 22, x: 0, y: 13)

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
            Circle()
                .fill(Color(red: 0.62, green: 0.94, blue: 0.82).opacity(0.18))
                .blur(radius: 28)
                .frame(width: panelSize.width * 0.56, height: panelSize.width * 0.56)
                .offset(x: -panelSize.width * 0.24, y: -panelSize.height * 0.28)
            Circle()
                .fill(Color(red: 0.45, green: 0.68, blue: 1.00).opacity(0.13))
                .blur(radius: 34)
                .frame(width: panelSize.width * 0.58, height: panelSize.width * 0.58)
                .offset(x: panelSize.width * 0.30, y: panelSize.height * 0.22)
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.12),
                            .white.opacity(0.01),
                            .black.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .allowsHitTesting(false)
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
