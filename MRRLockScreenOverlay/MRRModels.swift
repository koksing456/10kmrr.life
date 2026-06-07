import Foundation

struct MRRResult: Codable, Equatable {
    var minorUnitsByCurrency: [String: Int64]
    var excludedMeteredItems: Int
    var excludedFreeItems: Int

    var isEmpty: Bool {
        minorUnitsByCurrency.isEmpty
    }
}
