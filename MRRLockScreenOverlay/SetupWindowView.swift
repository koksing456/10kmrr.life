import AppKit
import SwiftUI

struct SetupWindowView: View {
    @StateObject private var model = SetupModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text("10kmrr.life Setup")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                Text("Store a restricted read-only Stripe key in macOS Keychain.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(AppBuildInfo.displayText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.tertiary)
            }

            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(model.isConfigured ? Color.green : Color.orange)
                        .frame(width: 9, height: 9)
                    Text(model.statusText)
                        .font(.system(size: 14, weight: .semibold))
                }
                Text("Use a restricted key with read access to Stripe Billing subscriptions and prices. Full-access sk_ keys are refused.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Stripe restricted key")
                    .font(.system(size: 13, weight: .semibold))
                SecureField("rk_live_...", text: $model.keyInput)
                    .textFieldStyle(.roundedBorder)
                HStack(spacing: 10) {
                    Button("Save Key") {
                        model.saveKey()
                    }
                    .keyboardShortcut(.defaultAction)

                    Button("Preview Mock Overlay") {
                        openMockPreview()
                    }

                    Button(model.isRefreshingMRR ? "Refreshing..." : "Refresh MRR") {
                        Task {
                            await model.refreshMRR()
                        }
                    }
                    .disabled(model.isRefreshingMRR || !model.isConfigured)

                    Button("Delete Key", role: .destructive) {
                        model.deleteKey()
                    }
                    .disabled(!model.isConfigured)
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("Refresh status")
                    .font(.system(size: 13, weight: .semibold))
                Text(model.lastRefreshText)
                    .font(.system(size: 13, weight: .medium))
                Text(model.cacheDetailText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Overlay settings")
                    .font(.system(size: 13, weight: .semibold))
                HStack(spacing: 18) {
                    Picker("Refresh", selection: $model.refreshIntervalMinutes) {
                        ForEach(model.refreshIntervalOptions, id: \.self) { minutes in
                            Text("\(minutes)m").tag(minutes)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 236)

                    Picker("Position", selection: $model.placement) {
                        ForEach(OverlayPlacement.allCases) { placement in
                            Text(placement.label).tag(placement)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 222)
                }
                HStack(spacing: 18) {
                    Picker("Horizontal", selection: $model.horizontalPlacement) {
                        ForEach(OverlayHorizontalPlacement.allCases) { placement in
                            Text(placement.label).tag(placement)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 236)

                    Picker("Size", selection: $model.sizePreset) {
                        ForEach(OverlaySizePreset.allCases) { sizePreset in
                            Text(sizePreset.label).tag(sizePreset)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 222)
                }
                Picker("Display", selection: $model.displayMode) {
                    ForEach(OverlayDisplayMode.allCases) { displayMode in
                        Text(displayMode.label).tag(displayMode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 236)
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

            if !model.testText.isEmpty {
                Text(model.testText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            HStack {
                Spacer()
                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
        .padding(26)
        .frame(width: 560)
    }

    private func openMockPreview() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.arguments = ["--preview", "--private-glass", "--mock-mrr"]
        configuration.activates = true
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration)
    }
}
