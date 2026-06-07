import AppKit
import SwiftUI

struct SetupWindowView: View {
    @StateObject var model = SetupModel()
    @State private var didPreviewMock = false
    @State var showsAdvancedSettings = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                firstRunCard
                keyCard
                cacheCard
                installSupportCard
                advancedSettings
                statusMessage
                footer
            }
            .padding(26)
        }
        .frame(width: 640, height: 720)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Set up your Lock Screen MRR")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                Text("Preview first, save a restricted Stripe key in Keychain, then install the local overlay.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(AppBuildInfo.displayText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
            SetupStatusBadge(text: model.isConfigured ? "Key ready" : "Needs key", isReady: model.isConfigured)
        }
    }

    private var firstRunCard: some View {
        SetupCard {
            SetupProgressView(
                didPreviewMock: didPreviewMock,
                isConfigured: model.isConfigured,
                hasCache: !model.lastRefreshText.hasPrefix("No cached"),
                openMockPreview: openMockPreview
            )
        }
    }

    private var keyCard: some View {
        SetupCard {
            VStack(alignment: .leading, spacing: 14) {
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

                SecureField("rk_live_...", text: $model.keyInput)
                    .textFieldStyle(.roundedBorder)
                HStack(spacing: 10) {
                    Button("Save Restricted Key") {
                        model.saveKey()
                    }
                    .keyboardShortcut(.defaultAction)

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
        }
    }

    private var cacheCard: some View {
        SetupCard {
            VStack(alignment: .leading, spacing: 7) {
                SetupSectionTitle("Local MRR cache")
                Text(model.lastRefreshText)
                    .font(.system(size: 13, weight: .medium))
                Text(model.cacheDetailText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var installSupportCard: some View {
        SetupCard {
            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .firstTextBaseline) {
                    SetupSectionTitle("Install & support")
                    Spacer()
                    Text(model.localSupport.sourceRootURL == nil ? "Manual" : "Source ready")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(model.localSupport.sourceRootURL == nil ? .secondary : Color.green)
                }

                Text(model.localSupport.sourceStatusText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Button(model.isRunningDiagnostic ? "Running..." : "Run Diagnose") {
                        Task {
                            await model.runDiagnostic()
                        }
                    }
                    .disabled(!model.canRunDiagnostic)

                    Button("Copy Install") {
                        model.copyInstallCommand()
                    }

                    Button("Copy Support Report") {
                        model.copySupportReportCommand()
                    }

                    Button("Open Logs") {
                        model.openLogsFolder()
                    }
                }

                Text(model.supportText)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var statusMessage: some View {
        if !model.testText.isEmpty {
            SetupCard {
                Text(model.testText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 16) {
            Divider()

            HStack {
                Text("After setup, copy the install command here or run ./script/start_alpha.sh from the checkout.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
    }

    private func openMockPreview() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.arguments = ["--preview", "--private-glass", "--mock-mrr"]
        configuration.activates = true
        configuration.createsNewApplicationInstance = true
        didPreviewMock = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration)
    }

}
