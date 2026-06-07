import Foundation

private enum TestFailure: Error, CustomStringConvertible {
    case mismatch(String)

    var description: String {
        switch self {
        case let .mismatch(message):
            return message
        }
    }
}

@main
private enum MRRCacheStoreTests {
    private static let suiteName = "life.10kmrr.MRRLockScreenOverlay.Cache.Tests.\(getpid())"

    static func main() {
        do {
            setenv("TENKMRR_CACHE_SUITE", suiteName, 1)
            cleanup()
            defer { cleanup() }

            try testMissingCache()
            try testSaveAndLoad()
            try testMissingTimestampStillLoadsMRR()
            try testCorruptCacheReturnsNil()

            print("MRR cache tests passed (4 cases).")
        } catch {
            fputs("\(error)\n", stderr)
            cleanup()
            exit(1)
        }
    }

    private static func testMissingCache() throws {
        cleanup()
        try assertNil(MRRCacheStore.load(), "missing cache should load nil")
    }

    private static func testSaveAndLoad() throws {
        let result = MRRResult(
            minorUnitsByCurrency: ["eur": 9_900, "usd": 12_345],
            excludedMeteredItems: 2,
            excludedFreeItems: 3
        )
        let date = Date(timeIntervalSince1970: 1_717_171_717)

        MRRCacheStore.save(result: result, lastUpdated: date)
        let loaded = try requireSnapshot(MRRCacheStore.load(), "saved cache should load")

        try assertEqual(loaded.result, result, "cached MRR result should round-trip")
        try assertEqual(loaded.lastUpdated, date, "cached timestamp should round-trip")
    }

    private static func testMissingTimestampStillLoadsMRR() throws {
        let result = MRRResult(
            minorUnitsByCurrency: ["usd": 10_248_00],
            excludedMeteredItems: 0,
            excludedFreeItems: 1
        )
        let data = try JSONEncoder().encode(result)
        let defaults = UserDefaults(suiteName: suiteName)!
        cleanup()
        defaults.set(data, forKey: "lastGoodMRR")

        let loaded = try requireSnapshot(MRRCacheStore.load(), "cache without timestamp should still load")

        try assertEqual(loaded.result, result, "cache result without timestamp")
        try assertEqual(loaded.lastUpdated, nil, "missing timestamp should stay nil")
    }

    private static func testCorruptCacheReturnsNil() throws {
        let defaults = UserDefaults(suiteName: suiteName)!
        cleanup()
        defaults.set(Data("not-json".utf8), forKey: "lastGoodMRR")
        defaults.set(Date(timeIntervalSince1970: 1), forKey: "lastUpdated")

        try assertNil(MRRCacheStore.load(), "corrupt cache should load nil")
    }

    private static func cleanup() {
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
    }

    private static func requireSnapshot(_ snapshot: MRRCacheSnapshot?, _ message: String) throws -> MRRCacheSnapshot {
        guard let snapshot else {
            throw TestFailure.mismatch(message)
        }
        return snapshot
    }

    private static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) throws {
        guard actual == expected else {
            throw TestFailure.mismatch("\(message). Expected \(expected), got \(actual).")
        }
    }

    private static func assertNil<T>(_ actual: T?, _ message: String) throws {
        guard actual == nil else {
            throw TestFailure.mismatch("\(message). Expected nil, got \(actual!).")
        }
    }
}
