import SwiftUI

extension SetupWindowView {
    var advancedSettings: some View {
        SetupCard {
            DisclosureGroup("Advanced overlay settings", isExpanded: $showsAdvancedSettings) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 18) {
                        settingPicker("Refresh", width: 236, selection: $model.refreshIntervalMinutes) {
                            ForEach(model.refreshIntervalOptions, id: \.self) { minutes in
                                Text("\(minutes)m").tag(minutes)
                            }
                        }
                        settingPicker("Position", width: 222, selection: $model.placement) {
                            ForEach(OverlayPlacement.allCases) { placement in
                                Text(placement.label).tag(placement)
                            }
                        }
                    }
                    HStack(spacing: 18) {
                        settingPicker("Horizontal", width: 236, selection: $model.horizontalPlacement) {
                            ForEach(OverlayHorizontalPlacement.allCases) { placement in
                                Text(placement.label).tag(placement)
                            }
                        }
                        settingPicker("Size", width: 222, selection: $model.sizePreset) {
                            ForEach(OverlaySizePreset.allCases) { sizePreset in
                                Text(sizePreset.label).tag(sizePreset)
                            }
                        }
                    }
                    settingPicker("Display", width: 236, selection: $model.displayMode) {
                        ForEach(OverlayDisplayMode.allCases) { displayMode in
                            Text(displayMode.label).tag(displayMode)
                        }
                    }
                    settingPicker("Style", width: 500, selection: $model.visualStyle) {
                        ForEach(OverlayVisualStyle.allCases) { visualStyle in
                            Text(visualStyle.label).tag(visualStyle)
                        }
                    }
                    HStack(spacing: 10) {
                        TextField("Goal currency", text: $model.goalCurrencyInput)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 116)
                        TextField("Goal MRR amount", text: $model.goalAmountInput)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 166)
                        Text("Used by Goal style")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 10) {
                        Button("Save Settings") {
                            model.saveSettings()
                        }
                        Button("Reset Settings") {
                            model.resetSettings()
                        }
                    }
                    Text("Settings are stored locally and apply the next time the overlay starts.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 12)
            }
            .font(.system(size: 13, weight: .semibold))
        }
    }

    func settingPicker<SelectionValue: Hashable, Content: View>(
        _ title: String,
        width: CGFloat,
        selection: Binding<SelectionValue>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Picker(title, selection: selection, content: content)
            .pickerStyle(.segmented)
            .frame(width: width)
    }
}
