import Foundation

final class StripeMRRClient {
    private let apiKey: String
    private let session: URLSession
    private let maxPagesPerStatus = 100

    private struct StripeSubscriptionPage {
        var subscriptions: [[String: Any]]
        var hasMore: Bool
    }

    init(apiKey: String) {
        self.apiKey = apiKey
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)
    }

    func fetchMRR() async throws -> MRRResult {
        var subscriptions: [[String: Any]] = []
        try await fetchAll(status: "active", into: &subscriptions)
        try await fetchAll(status: "past_due", into: &subscriptions)
        return MRRCalculator.calculate(from: subscriptions)
    }

    private func fetchAll(status: String, into subscriptions: inout [[String: Any]]) async throws {
        var startingAfter: String?

        for _ in 0..<maxPagesPerStatus {
            let page = try await fetchPage(status: status, startingAfter: startingAfter)
            subscriptions.append(contentsOf: page.subscriptions)

            guard page.hasMore else { return }
            guard let lastID = page.subscriptions.last?["id"] as? String else {
                throw OverlayError.invalidResponse
            }
            startingAfter = lastID
        }

        throw OverlayError.stripePaginationLimit(status)
    }

    private func fetchPage(status: String, startingAfter: String?) async throws -> StripeSubscriptionPage {
        var components = URLComponents(string: "https://api.stripe.com/v1/subscriptions")!
        var queryItems = [
            URLQueryItem(name: "status", value: status),
            URLQueryItem(name: "limit", value: "100"),
            URLQueryItem(name: "expand[]", value: "data.items.data.price"),
            URLQueryItem(name: "expand[]", value: "data.discount.coupon")
        ]
        if let startingAfter {
            queryItems.append(URLQueryItem(name: "starting_after", value: startingAfter))
        }
        components.queryItems = queryItems

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw OverlayError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 401 || http.statusCode == 403 {
                throw OverlayError.stripePermissionHint
            }
            throw OverlayError.stripeHTTP(http.statusCode, Self.safeStripeErrorMessage(from: data))
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw OverlayError.invalidResponse
        }

        let page = json["data"] as? [[String: Any]] ?? []
        let hasMore = (json["has_more"] as? NSNumber)?.boolValue ?? false
        return StripeSubscriptionPage(subscriptions: page, hasMore: hasMore)
    }

    private static func safeStripeErrorMessage(from data: Data) -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? [String: Any]
        else {
            return "No public error message was available."
        }

        let type = error["type"] as? String
        let code = error["code"] as? String
        let message = (error["message"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let publicParts = [type, code, message]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        guard !publicParts.isEmpty else {
            return "No public error message was available."
        }

        let joined = publicParts.joined(separator: ": ")
        if joined.count > 220 {
            return String(joined.prefix(217)) + "..."
        }
        return joined
    }
}
