import Foundation
import SwiftUI

@MainActor
final class MRRDisplayModel: ObservableObject {
    @Published var result: MRRResult?
    @Published var lastUpdated: Date?
    @Published var staleSince: Date?
    @Published var statusText = "Preparing MRR"
    @Published var isRefreshing = false
    @Published var errorText: String?

    init() {
        if mockMRRMode {
            loadMockMRR()
            return
        }
        loadCache()
    }

    var primaryValue: String {
        guard let result, !result.isEmpty else { return "--" }
        return result.minorUnitsByCurrency
            .sorted { $0.key < $1.key }
            .map { Self.format(minorUnits: $0.value, currency: $0.key) }
            .joined(separator: "  ")
    }

    var timestampText: String {
        guard let lastUpdated else { return "Waiting for first refresh" }
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return "Updated \(formatter.string(from: lastUpdated))"
    }

    var detailText: String {
        if let errorText, result != nil {
            return "Showing cached value. \(errorText)"
        }
        if let errorText {
            return errorText
        }
        if isRefreshing {
            return "Refreshing Stripe subscriptions"
        }
        return "Stripe MRR"
    }

    func amountMinorUnits(for currency: String) -> Int64? {
        let normalized = currency.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return nil }
        return result?.minorUnitsByCurrency[normalized]
    }

    func displayValue(minorUnits: Int64, currency: String) -> String {
        Self.format(minorUnits: minorUnits, currency: currency)
    }

    func refresh() async {
        guard !isRefreshing else { return }
        guard !mockMRRMode else {
            loadMockMRR()
            return
        }
        isRefreshing = true
        errorText = nil
        statusText = "Refreshing"

        do {
            let apiKey = try KeychainStore.readStripeAPIKey()
            let client = StripeMRRClient(apiKey: apiKey)
            let fetched = try await client.fetchMRR()
            result = fetched
            lastUpdated = Date()
            staleSince = nil
            statusText = "Live"
            saveCache(fetched, lastUpdated: lastUpdated)
        } catch {
            staleSince = Date()
            statusText = result == nil ? Self.safeStatusText(for: error) : "Stale"
            errorText = error.localizedDescription
        }

        isRefreshing = false
    }

    private static func format(minorUnits: Int64, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.uppercased()
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        let value = Decimal(minorUnits) / Decimal(100)
        return formatter.string(from: value as NSDecimalNumber) ?? "\(currency.uppercased()) \(value)"
    }

    private static func safeStatusText(for error: Error) -> String {
        if case OverlayError.missingAPIKey = error {
            return "Setup needed"
        }
        if case OverlayError.stripePermissionHint = error {
            return "Check key"
        }
        return "Refresh failed"
    }

    private func loadCache() {
        guard let snapshot = MRRCacheStore.load() else { return }
        result = snapshot.result
        lastUpdated = snapshot.lastUpdated
        statusText = "Cached"
    }

    private func loadMockMRR() {
        result = MRRResult(
            minorUnitsByCurrency: ["usd": 1024800],
            excludedMeteredItems: 0,
            excludedFreeItems: 0
        )
        lastUpdated = Date()
        staleSince = nil
        statusText = "Mock"
        errorText = nil
        isRefreshing = false
    }

    private func saveCache(_ result: MRRResult, lastUpdated: Date?) {
        guard let lastUpdated else { return }
        MRRCacheStore.save(result: result, lastUpdated: lastUpdated)
    }
}
