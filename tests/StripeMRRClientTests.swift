import Foundation

private final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: TestFailure.missingHandler)
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private final class RequestLog {
    private let lock = NSLock()
    private var requests: [URLRequest] = []

    func record(_ request: URLRequest) {
        lock.lock()
        requests.append(request)
        lock.unlock()
    }

    func count(status: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return requests.filter { Self.queryValue("status", in: $0) == status }.count
    }

    func request(at index: Int) -> URLRequest {
        lock.lock()
        defer { lock.unlock() }
        return requests[index]
    }

    static func queryValue(_ name: String, in request: URLRequest) -> String? {
        guard let url = request.url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else {
            return nil
        }
        return components.queryItems?.first(where: { $0.name == name })?.value
    }

    static func queryValues(_ name: String, in request: URLRequest) -> [String] {
        guard let url = request.url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else {
            return []
        }
        return components.queryItems?
            .filter { $0.name == name }
            .compactMap(\.value) ?? []
    }
}

private enum TestFailure: Error, CustomStringConvertible {
    case missingHandler
    case mismatch(String)
    case expectedError(String)

    var description: String {
        switch self {
        case .missingHandler:
            return "MockURLProtocol handler was not configured."
        case let .mismatch(message):
            return message
        case let .expectedError(message):
            return message
        }
    }
}

@main
private enum StripeMRRClientTests {
    static func main() async {
        do {
            try await testRetriesTransientStripeHTTP()
            try await testDoesNotRetryPermissionFailure()
            try await testStopsAtPaginationLimit()
            print("Stripe client tests passed (3 cases).")
        } catch {
            fputs("\(error)\n", stderr)
            exit(1)
        }
    }

    private static func testRetriesTransientStripeHTTP() async throws {
        let log = RequestLog()
        MockURLProtocol.handler = { request in
            log.record(request)
            let status = RequestLog.queryValue("status", in: request)
            if status == "active", log.count(status: "active") == 1 {
                return response(statusCode: 429, body: errorBody(type: "rate_limit_error", code: "rate_limit"))
            }
            if status == "active" {
                return response(statusCode: 200, body: pageBody(subscriptions: [subscription(id: "sub_active", amount: 10_000)], hasMore: false))
            }
            return response(statusCode: 200, body: pageBody(subscriptions: [], hasMore: false))
        }

        let result = try await client(maxRequestAttempts: 3).fetchMRR()

        try assertEqual(result.minorUnitsByCurrency["usd"], 10_000, "retry test should return active MRR")
        try assertEqual(log.count(status: "active"), 2, "retry test should make two active requests")
        try assertEqual(log.count(status: "past_due"), 1, "retry test should still fetch past_due")
        try assertEqual(
            log.request(at: 0).value(forHTTPHeaderField: "Authorization"),
            "Bearer restricted_mock_key",
            "client should send bearer auth"
        )
        try assertEqual(
            RequestLog.queryValues("expand[]", in: log.request(at: 0)),
            ["data.items.data.price", "data.discount.coupon", "data.discounts", "data.items.data.discounts"],
            "client should expand prices and both subscription/item discounts"
        )
    }

    private static func testDoesNotRetryPermissionFailure() async throws {
        let log = RequestLog()
        MockURLProtocol.handler = { request in
            log.record(request)
            return response(statusCode: 403, body: errorBody(type: "invalid_request_error", code: "permission_error"))
        }

        do {
            _ = try await client(maxRequestAttempts: 3).fetchMRR()
            throw TestFailure.expectedError("permission test should throw")
        } catch OverlayError.stripePermissionHint {
            try assertEqual(log.count(status: "active"), 1, "permission failure should not retry")
            try assertEqual(log.count(status: "past_due"), 0, "permission failure should stop before past_due")
        }
    }

    private static func testStopsAtPaginationLimit() async throws {
        let log = RequestLog()
        MockURLProtocol.handler = { request in
            log.record(request)
            let startingAfter = RequestLog.queryValue("starting_after", in: request)
            let id = startingAfter == nil ? "sub_page_1" : "sub_page_2"
            return response(statusCode: 200, body: pageBody(subscriptions: [subscription(id: id, amount: 1_000)], hasMore: true))
        }

        do {
            _ = try await client(maxPagesPerStatus: 2).fetchMRR()
            throw TestFailure.expectedError("pagination test should throw")
        } catch OverlayError.stripePaginationLimit(let status) {
            try assertEqual(status, "active", "pagination limit should identify active status")
            try assertEqual(log.count(status: "active"), 2, "pagination limit should stop at configured cap")
            try assertEqual(
                RequestLog.queryValue("starting_after", in: log.request(at: 1)),
                "sub_page_1",
                "pagination should use the previous page's last subscription id"
            )
        }
    }

    private static func client(maxPagesPerStatus: Int = 100, maxRequestAttempts: Int = 3) -> StripeMRRClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        return StripeMRRClient(
            apiKey: "restricted_mock_key",
            session: session,
            maxPagesPerStatus: maxPagesPerStatus,
            maxRequestAttempts: maxRequestAttempts,
            retryBaseDelayNanoseconds: 0
        )
    }

    private static func response(statusCode: Int, body: Data) -> (HTTPURLResponse, Data) {
        let url = URL(string: "https://api.stripe.com/v1/subscriptions")!
        return (
            HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!,
            body
        )
    }

    private static func pageBody(subscriptions: [[String: Any]], hasMore: Bool) -> Data {
        let root: [String: Any] = [
            "object": "list",
            "data": subscriptions,
            "has_more": hasMore
        ]
        return try! JSONSerialization.data(withJSONObject: root)
    }

    private static func errorBody(type: String, code: String) -> Data {
        let root: [String: Any] = [
            "error": [
                "type": type,
                "code": code,
                "message": "Mock Stripe error"
            ]
        ]
        return try! JSONSerialization.data(withJSONObject: root)
    }

    private static func subscription(id: String, amount: Int) -> [String: Any] {
        [
            "id": id,
            "status": "active",
            "items": [
                "data": [
                    [
                        "quantity": 1,
                        "price": [
                            "currency": "usd",
                            "unit_amount": amount,
                            "recurring": [
                                "interval": "month",
                                "interval_count": 1,
                                "usage_type": "licensed"
                            ]
                        ]
                    ]
                ]
            ]
        ]
    }

    private static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) throws {
        guard actual == expected else {
            throw TestFailure.mismatch("\(message). Expected \(expected), got \(actual).")
        }
    }
}
