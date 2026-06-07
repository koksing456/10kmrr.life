import SwiftUI

extension SetupWindowView {
    var installSupportCard: some View {
        SetupCard {
            VStack(alignment: .leading, spacing: 13) {
                supportHeader

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

                    Button(model.isGeneratingSupportReport ? "Generating..." : "Generate Report") {
                        Task {
                            await model.generateSupportReport()
                        }
                    }
                    .disabled(!model.canGenerateSupportReport)

                    Button("Open Report") {
                        model.openSupportReport()
                    }
                }

                HStack(spacing: 10) {
                    Button("Copy Install") {
                        model.copyInstallCommand()
                    }

                    Button("Copy Support Cmd") {
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

    private var supportHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            SetupSectionTitle("Install & support")
            Spacer()
            Text(model.localSupport.sourceRootURL == nil ? "Manual" : "Source ready")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(model.localSupport.sourceRootURL == nil ? .secondary : Color.green)
        }
    }
}
