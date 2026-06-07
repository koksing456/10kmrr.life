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

    private let defaults = UserDefaults(suiteName: "life.10kmrr.MRRLockScreenOverlay.Cache") ?? .standard

    init() {
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

    func refresh() async {
        guard !isRefreshing else { return }
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
            saveCache()
        } catch {
            staleSince = Date()
            statusText = result == nil ? "Needs attention" : "Stale"
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

    private func loadCache() {
        guard let data = defaults.data(forKey: "lastGoodMRR"),
              let cached = try? JSONDecoder().decode(MRRResult.self, from: data)
        else {
            return
        }
        result = cached
        lastUpdated = defaults.object(forKey: "lastUpdated") as? Date
        statusText = "Cached"
    }

    private func saveCache() {
        guard let result, let data = try? JSONEncoder().encode(result) else { return }
        defaults.set(data, forKey: "lastGoodMRR")
        defaults.set(lastUpdated, forKey: "lastUpdated")
    }
}
