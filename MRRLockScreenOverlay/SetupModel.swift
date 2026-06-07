import Foundation
import SwiftUI

@MainActor
final class SetupModel: ObservableObject {
    let refreshIntervalOptions = [1, 5, 10, 15, 30]

    @Published var keyInput = ""
    @Published var statusText = ""
    @Published var testText = ""
    @Published var isConfigured = false
    @Published var isTesting = false
    @Published var refreshIntervalMinutes = 5
    @Published var placement = OverlayPlacement.center

    init() {
        refreshStatus()
        loadSettings()
    }

    func refreshStatus() {
        isConfigured = KeychainStore.stripeAPIKeyExists()
        statusText = isConfigured ? "Keychain key configured" : "Keychain key not configured"
    }

    func loadSettings() {
        let storedRefreshInterval = OverlaySettingsStore.refreshIntervalMinutes
        refreshIntervalMinutes = refreshIntervalOptions.contains(storedRefreshInterval) ? storedRefreshInterval : 5
        placement = OverlaySettingsStore.placement
    }

    func saveSettings() {
        OverlaySettingsStore.refreshIntervalMinutes = refreshIntervalMinutes
        OverlaySettingsStore.placement = placement
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
            testText = "Removed Keychain key"
        } catch {
            statusText = "Keychain delete failed"
            testText = error.localizedDescription
        }
    }

    func testStripe() async {
        guard !isTesting else { return }
        isTesting = true
        testText = "Testing Stripe access"

        do {
            let apiKey = try KeychainStore.readStripeAPIKey()
            let result = try await StripeMRRClient(apiKey: apiKey).fetchMRR()
            let currencyCount = result.minorUnitsByCurrency.count
            testText = currencyCount == 1
                ? "Stripe test passed for 1 currency"
                : "Stripe test passed for \(currencyCount) currencies"
            refreshStatus()
        } catch {
            testText = error.localizedDescription
            refreshStatus()
        }

        isTesting = false
    }
}
