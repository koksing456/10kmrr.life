import Foundation

enum AppLogger {
    static func log(_ event: String, fields: [String: String] = [:]) {
        var parts = ["event=\(sanitize(event))"]
        for key in fields.keys.sorted() {
            guard let value = fields[key] else { continue }
            parts.append("\(sanitize(key))=\(sanitize(value))")
        }
        NSLog("%@: %@", appSubsystem, parts.joined(separator: " "))
    }

    static func errorKind(_ error: Error) -> String {
        if let overlayError = error as? OverlayError {
            switch overlayError {
            case .missingAPIKey:
                return "missing_api_key"
            case .invalidResponse:
                return "invalid_response"
            case .stripeHTTP:
                return "stripe_http"
            case .stripePermissionHint:
                return "stripe_permission"
            case .stripePaginationLimit:
                return "stripe_pagination_limit"
            case .skylightUnavailable:
                return "skylight_unavailable"
            }
        }

        if let urlError = error as? URLError {
            return "url_error_\(urlError.code.rawValue)"
        }

        return String(describing: type(of: error))
    }

    private static func sanitize(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        return String(value.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" })
    }
}
