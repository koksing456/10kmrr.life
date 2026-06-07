import SwiftUI

struct MRRLockOverlayView: View {
    @ObservedObject var model: MRRDisplayModel
    @State var pulse = false

    let cornerRadius: CGFloat = 34

    var panelSize: NSSize {
        OverlaySettingsStore.panelSize
    }

    var sizePreset: OverlaySizePreset {
        OverlaySettingsStore.sizePreset
    }

    var visualStyle: OverlayVisualStyle {
        OverlaySettingsStore.visualStyle
    }

    var contentSpacing: CGFloat {
        switch visualStyle {
        case .hero:
            return 12
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
    var panelContent: some View {
        if visualStyle == .hero {
            heroContent
        } else if visualStyle == .focus {
            focusContent
        } else {
            VStack(alignment: .leading, spacing: contentSpacing) {
                if visualStyle != .number {
                    headerRow
                }

                valueText

                switch visualStyle {
                case .hero:
                    EmptyView()
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
}
