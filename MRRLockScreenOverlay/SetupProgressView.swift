import SwiftUI

struct SetupProgressView: View {
    let isConfigured: Bool
    let hasCache: Bool
    let openMockPreview: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("First run")
                .font(.system(size: 13, weight: .semibold))

            HStack(alignment: .top, spacing: 12) {
                progressStep(
                    number: "1",
                    title: "Preview",
                    detail: "Mock MRR",
                    isComplete: true
                )

                progressStep(
                    number: "2",
                    title: "Keychain",
                    detail: isConfigured ? "Ready" : "Restricted key",
                    isComplete: isConfigured
                )

                progressStep(
                    number: "3",
                    title: "Refresh",
                    detail: hasCache ? "Cache ready" : "Stripe test",
                    isComplete: hasCache
                )

                Spacer(minLength: 0)

                Button("Preview Mock") {
                    openMockPreview()
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.055))
        )
    }

    private func progressStep(number: String, title: String, detail: String, isComplete: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            ZStack {
                Circle()
                    .fill(isComplete ? Color.green.opacity(0.22) : Color.secondary.opacity(0.14))
                    .frame(width: 24, height: 24)
                Text(isComplete ? "✓" : number)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(isComplete ? Color.green : Color.secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Text(detail)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: 112, alignment: .leading)
    }
}
