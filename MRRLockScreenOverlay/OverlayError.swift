import Foundation

enum OverlayError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case stripeHTTP(Int, String)
    case stripePermissionHint
    case stripePaginationLimit(String)
    case skylightUnavailable

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Stripe key is not configured. Run setup to add a restricted read-only key."
        case .invalidResponse:
            return "Stripe returned an invalid response."
        case let .stripeHTTP(status, message):
            return "Stripe returned HTTP \(status). \(message)"
        case .stripePermissionHint:
            return "Stripe key cannot read the required Billing resources. Check restricted key permissions."
        case let .stripePaginationLimit(status):
            return "Stripe pagination exceeded the local safety limit while reading \(status) subscriptions."
        case .skylightUnavailable:
            return "Private SkyLight APIs are unavailable on this macOS build."
        }
    }
}
