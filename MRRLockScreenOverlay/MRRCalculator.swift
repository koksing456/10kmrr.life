import Foundation

enum MRRCalculator {
    static func calculate(from subscriptions: [[String: Any]]) -> MRRResult {
        var totals: [String: Int64] = [:]
        var excludedMetered = 0
        var excludedFree = 0

        for subscription in subscriptions {
            let status = subscription["status"] as? String ?? ""
            guard status == "active" || status == "past_due" else { continue }

            let itemsContainer = subscription["items"] as? [String: Any]
            let items = itemsContainer?["data"] as? [[String: Any]] ?? []
            for item in items {
                let price = item["price"] as? [String: Any] ?? [:]
                let recurring = price["recurring"] as? [String: Any] ?? [:]
                if (recurring["usage_type"] as? String) == "metered" {
                    excludedMetered += 1
                    continue
                }

                let unitAmount = unitAmountMinorUnits(from: price)
                let quantity = (item["quantity"] as? NSNumber)?.intValue ?? 1
                if unitAmount <= 0 || quantity <= 0 {
                    excludedFree += 1
                    continue
                }

                var monthlyAmount = monthlyAmountMinorUnits(unitAmount: unitAmount, recurring: recurring) * Double(quantity)
                monthlyAmount = applyDiscounts(subscription["discounts"], to: monthlyAmount)
                if let legacyDiscount = subscription["discount"] as? [String: Any] {
                    monthlyAmount = applyDiscounts([legacyDiscount], to: monthlyAmount)
                }
                monthlyAmount = applyDiscounts(item["discounts"], to: monthlyAmount)

                let currency = (price["currency"] as? String ?? "").lowercased()
                guard !currency.isEmpty, monthlyAmount > 0 else { continue }
                totals[currency, default: 0] += Int64(monthlyAmount.rounded())
            }
        }

        return MRRResult(
            minorUnitsByCurrency: totals,
            excludedMeteredItems: excludedMetered,
            excludedFreeItems: excludedFree
        )
    }

    private static func unitAmountMinorUnits(from price: [String: Any]) -> Double {
        if let decimal = price["unit_amount_decimal"] as? String {
            return Double(decimal) ?? 0
        }
        return (price["unit_amount"] as? NSNumber)?.doubleValue ?? 0
    }

    private static func monthlyAmountMinorUnits(unitAmount: Double, recurring: [String: Any]) -> Double {
        let interval = recurring["interval"] as? String ?? "month"
        let count = max(1, (recurring["interval_count"] as? NSNumber)?.intValue ?? 1)

        switch interval {
        case "day":
            return unitAmount * 30 / Double(count)
        case "week":
            return unitAmount * (52 / 12) / Double(count)
        case "year":
            return unitAmount / (12 * Double(count))
        default:
            return unitAmount / Double(count)
        }
    }

    private static func applyDiscounts(_ object: Any?, to amount: Double) -> Double {
        var discounts: [[String: Any]] = []
        if let array = object as? [[String: Any]] {
            discounts = array
        } else if let container = object as? [String: Any] {
            discounts = container["data"] as? [[String: Any]] ?? [container]
        }

        var result = amount
        for discount in discounts {
            guard let coupon = coupon(from: discount) else { continue }
            if let percent = (coupon["percent_off"] as? NSNumber)?.doubleValue {
                result *= max(0, 1 - percent / 100)
            }
            if let amountOff = (coupon["amount_off"] as? NSNumber)?.doubleValue {
                let duration = coupon["duration"] as? String ?? ""
                if duration == "forever" || duration.isEmpty {
                    result = max(0, result - amountOff)
                }
            }
        }
        return result
    }

    private static func coupon(from discount: [String: Any]) -> [String: Any]? {
        if let coupon = discount["coupon"] as? [String: Any] {
            return coupon
        }

        guard let source = discount["source"] as? [String: Any],
              (source["type"] as? String) == "coupon"
        else {
            return nil
        }

        return source["coupon"] as? [String: Any]
    }
}
