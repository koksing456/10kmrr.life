import Foundation

struct MRRCacheSnapshot {
    var result: MRRResult
    var lastUpdated: Date?
}

enum MRRCacheStore {
    private static let suiteName = ProcessInfo.processInfo.environment["TENKMRR_CACHE_SUITE"]
        ?? "life.10kmrr.MRRLockScreenOverlay.Cache"
    private static let defaults = UserDefaults(suiteName: suiteName) ?? .standard
    private static let resultKey = "lastGoodMRR"
    private static let lastUpdatedKey = "lastUpdated"

    static func load() -> MRRCacheSnapshot? {
        guard let data = defaults.data(forKey: resultKey),
              let cached = try? JSONDecoder().decode(MRRResult.self, from: data)
        else {
            return nil
        }

        return MRRCacheSnapshot(
            result: cached,
            lastUpdated: defaults.object(forKey: lastUpdatedKey) as? Date
        )
    }

    static func save(result: MRRResult, lastUpdated: Date) {
        guard let data = try? JSONEncoder().encode(result) else { return }
        defaults.set(data, forKey: resultKey)
        defaults.set(lastUpdated, forKey: lastUpdatedKey)
    }
}
