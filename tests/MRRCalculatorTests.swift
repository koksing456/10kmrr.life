import Foundation

private struct FixtureCase {
    let name: String
    let subscriptions: [[String: Any]]
    let expectedMinorUnitsByCurrency: [String: Int64]
    let expectedExcludedMeteredItems: Int
    let expectedExcludedFreeItems: Int
}

private enum TestFailure: Error, CustomStringConvertible {
    case invalidFixture(String)
    case mismatch(caseName: String, field: String, expected: String, actual: String)

    var description: String {
        switch self {
        case let .invalidFixture(message):
            return "Invalid fixture: \(message)"
        case let .mismatch(caseName, field, expected, actual):
            return "\(caseName) failed for \(field). Expected \(expected), got \(actual)."
        }
    }
}

@main
private enum MRRCalculatorTests {
    static func main() {
        do {
            let fixturePath = try fixturePathFromArguments()
            let cases = try loadCases(from: fixturePath)
            for testCase in cases {
                try run(testCase)
            }
            print("MRR calculator tests passed (\(cases.count) cases).")
        } catch {
            fputs("\(error)\n", stderr)
            exit(1)
        }
    }

    private static func fixturePathFromArguments() throws -> String {
        guard CommandLine.arguments.count == 2 else {
            throw TestFailure.invalidFixture("usage: MRRCalculatorTests <fixture-json>")
        }
        return CommandLine.arguments[1]
    }

    private static func loadCases(from path: String) throws -> [FixtureCase] {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rawCases = root["cases"] as? [[String: Any]]
        else {
            throw TestFailure.invalidFixture("top-level cases array is missing")
        }

        return try rawCases.map { rawCase in
            guard let name = rawCase["name"] as? String,
                  let subscriptions = rawCase["subscriptions"] as? [[String: Any]],
                  let expected = rawCase["expectedMinorUnitsByCurrency"] as? [String: Any],
                  let expectedMetered = rawCase["expectedExcludedMeteredItems"] as? NSNumber,
                  let expectedFree = rawCase["expectedExcludedFreeItems"] as? NSNumber
            else {
                throw TestFailure.invalidFixture("case is missing required fields")
            }

            var expectedTotals: [String: Int64] = [:]
            for (currency, value) in expected {
                guard let number = value as? NSNumber else {
                    throw TestFailure.invalidFixture("\(name) has a non-numeric expected total for \(currency)")
                }
                expectedTotals[currency] = number.int64Value
            }

            return FixtureCase(
                name: name,
                subscriptions: subscriptions,
                expectedMinorUnitsByCurrency: expectedTotals,
                expectedExcludedMeteredItems: expectedMetered.intValue,
                expectedExcludedFreeItems: expectedFree.intValue
            )
        }
    }

    private static func run(_ testCase: FixtureCase) throws {
        let result = MRRCalculator.calculate(from: testCase.subscriptions)

        try assertEqual(
            result.minorUnitsByCurrency,
            testCase.expectedMinorUnitsByCurrency,
            caseName: testCase.name,
            field: "minorUnitsByCurrency"
        )
        try assertEqual(
            result.excludedMeteredItems,
            testCase.expectedExcludedMeteredItems,
            caseName: testCase.name,
            field: "excludedMeteredItems"
        )
        try assertEqual(
            result.excludedFreeItems,
            testCase.expectedExcludedFreeItems,
            caseName: testCase.name,
            field: "excludedFreeItems"
        )
    }

    private static func assertEqual<T: Equatable>(
        _ actual: T,
        _ expected: T,
        caseName: String,
        field: String
    ) throws {
        guard actual == expected else {
            throw TestFailure.mismatch(
                caseName: caseName,
                field: field,
                expected: "\(expected)",
                actual: "\(actual)"
            )
        }
    }
}
