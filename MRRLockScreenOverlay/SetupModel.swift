import Foundation
import SwiftUI

@MainActor
final class SetupModel: ObservableObject {
    let refreshIntervalOptions = [1, 5, 10, 15, 30]

    @Published var keyInput = ""
    @Published var statusText = ""
    @Published var testText = ""
    @Published var isConfigured = false
    @Published var isRefreshingMRR = false
    @Published var refreshIntervalMinutes = 5
    @Published var placement = OverlayPlacement.center
    @Published var horizontalPlacement = OverlayHorizontalPlacement.center
    @Published var sizePreset = OverlaySizePreset.medium
    @Published var displayMode = OverlayDisplayMode.main
    @Published var lastRefreshText = "No cached MRR refresh yet"
    @Published var cacheDetailText = "No last-good MRR cache found"

    init() {
        refreshStatus()
        loadSettings()
        refreshCacheStatus()
    }

    func refreshStatus() {
        isConfigured = KeychainStore.stripeAPIKeyExists()
        statusText = isConfigured ? "Keychain key configured" : "Keychain key not configured"
    }

    func refreshCacheStatus() {
        guard let snapshot = MRRCacheStore.load() else {
            lastRefreshText = "No cached MRR refresh yet"
            cacheDetailText = "Refresh after saving a restricted key to create the local last-good cache."
            return
        }

        if let lastUpdated = snapshot.lastUpdated {
            lastRefreshText = "Last MRR refresh: \(Self.formatTimestamp(lastUpdated))"
        } else {
            lastRefreshText = "Last MRR refresh: timestamp unavailable"
        }

        cacheDetailText = cacheSummary(forCurrencyCount: snapshot.result.minorUnitsByCurrency.count)
    }

    func loadSettings() {
        let storedRefreshInterval = OverlaySettingsStore.refreshIntervalMinutes
        refreshIntervalMinutes = refreshIntervalOptions.contains(storedRefreshInterval) ? storedRefreshInterval : 5
        placement = OverlaySettingsStore.placement
        horizontalPlacement = OverlaySettingsStore.horizontalPlacement
        sizePreset = OverlaySettingsStore.sizePreset
        displayMode = OverlaySettingsStore.displayMode
    }

    func saveSettings() {
        OverlaySettingsStore.refreshIntervalMinutes = refreshIntervalMinutes
        OverlaySettingsStore.placement = placement
        OverlaySettingsStore.horizontalPlacement = horizontalPlacement
        OverlaySettingsStore.sizePreset = sizePreset
        OverlaySettingsStore.displayMode = displayMode
        testText = "Saved display settings. Restart installed overlay to apply them."
    }

    func resetSettings() {
        OverlaySettingsStore.reset()
        loadSettings()
        testText = "Reset display settings"
    }

    func saveKey() {
        let trimmed = keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        testText = ""

        guard !trimmed.isEmpty else {
            statusText = "Enter a restricted Stripe key before saving"
            return
        }

        guard !trimmed.hasPrefix("sk_") else {
            statusText = "Refused full-access Stripe secret key"
            return
        }

        do {
            try KeychainStore.saveStripeAPIKey(trimmed)
            keyInput = ""
            refreshStatus()
            refreshCacheStatus()
            testText = trimmed.hasPrefix("rk_")
                ? "Saved restricted key"
                : "Saved key. Prefix was not rk_, so verify it is restricted in Stripe."
        } catch {
            statusText = "Keychain save failed"
            testText = error.localizedDescription
        }
    }

    func deleteKey() {
        do {
            try KeychainStore.deleteStripeAPIKey()
            keyInput = ""
            refreshStatus()
            refreshCacheStatus()
            testText = "Removed Keychain key"
        } catch {
            statusText = "Keychain delete failed"
            testText = error.localizedDescription
        }
    }

    func refreshMRR() async {
        guard !isRefreshingMRR else { return }
        isRefreshingMRR = true
        testText = "Refreshing MRR from Stripe"

        do {
            let apiKey = try KeychainStore.readStripeAPIKey()
            let result = try await StripeMRRClient(apiKey: apiKey).fetchMRR()
            let lastUpdated = Date()
            MRRCacheStore.save(result: result, lastUpdated: lastUpdated)
            let currencyCount = result.minorUnitsByCurrency.count
            testText = currencyCount == 1
                ? "Stripe refresh passed. Local cache updated for 1 currency."
                : "Stripe refresh passed. Local cache updated for \(currencyCount) currencies."
            refreshStatus()
            refreshCacheStatus()
        } catch {
            testText = error.localizedDescription
            refreshStatus()
            refreshCacheStatus()
        }

        isRefreshingMRR = false
    }

    private static func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func cacheSummary(forCurrencyCount currencyCount: Int) -> String {
        switch currencyCount {
        case 0:
            return "Last-good cache is ready, but no included recurring MRR was found. Exact values are only shown on the overlay."
        case 1:
            return "Last-good cache is ready for 1 currency. The exact value is only shown on the overlay."
        default:
            return "Last-good cache is ready for \(currencyCount) currencies. Exact values are only shown on the overlay."
        }
    }
}
