import Foundation

enum QuotaParser {
    static func codexSnapshot(fromRateLimitsResponse result: [String: Any]) -> [String: Any]? {
        if let byID = result["rateLimitsByLimitId"] as? [String: Any],
           let codex = byID["codex"] as? [String: Any] {
            return codex
        }
        return result["rateLimits"] as? [String: Any]
    }

    static func quota(fromRateLimitsResponse result: [String: Any]) -> Quota? {
        guard let snapshot = codexSnapshot(fromRateLimitsResponse: result) else { return nil }
        return quota(fromSnapshot: snapshot)
    }

    static func mergeSnapshot(base: [String: Any]?, update: [String: Any]) -> [String: Any] {
        var merged = base ?? [:]
        for (key, value) in update {
            // A sparse rate-limit update only replaces fields it actually carries.
            // Missing primary/secondary values must not erase the other window.
            merged[key] = value
        }
        return merged
    }

    static func quota(fromSnapshot snapshot: [String: Any]) -> Quota? {
        let primary = window(snapshot["primary"])
        let secondary = window(snapshot["secondary"])
        let windows = [primary, secondary].compactMap { $0 }
        guard !windows.isEmpty else { return nil }

        var fiveHour: Window?
        var weekly: Window?

        for item in windows {
            if let minutes = item.minutes {
                if (240...360).contains(minutes) { fiveHour = item }
                if (9_000...11_000).contains(minutes) { weekly = item }
            }
        }

        if windows.count == 2 {
            let sorted = windows.sorted { ($0.minutes ?? Int.max) < ($1.minutes ?? Int.max) }
            if fiveHour == nil { fiveHour = sorted.first }
            if weekly == nil { weekly = sorted.last }
        } else if let only = windows.first, let minutes = only.minutes {
            if fiveHour == nil, minutes < 1_000 { fiveHour = only }
            if weekly == nil, minutes >= 1_000 { weekly = only }
        }

        let fiveRemaining = fiveHour.map { remaining(fromUsed: $0.usedPercent) }
        let weekRemaining = weekly.map { remaining(fromUsed: $0.usedPercent) }

        return Quota(
            fiveHourPercent: fiveRemaining,
            weekPercent: weekRemaining,
            fiveHourResetsAt: fiveHour?.resetsAt,
            weekResetsAt: weekly?.resetsAt
        )
    }

    private struct Window {
        let usedPercent: Double
        let minutes: Int?
        let resetsAt: Date?
    }

    private static func window(_ raw: Any?) -> Window? {
        guard let object = raw as? [String: Any],
              let used = number(object["usedPercent"]) else { return nil }

        let minutes = number(object["windowDurationMins"]).map { Int($0.rounded()) }
        let resetsAt = number(object["resetsAt"]).map { Date(timeIntervalSince1970: $0) }

        return Window(
            usedPercent: used,
            minutes: minutes,
            resetsAt: resetsAt
        )
    }

    private static func number(_ raw: Any?) -> Double? {
        if let value = raw as? Double { return value }
        if let value = raw as? Int { return Double(value) }
        if let value = raw as? NSNumber { return value.doubleValue }
        return nil
    }

    private static func remaining(fromUsed used: Double) -> Int {
        Int(max(0, min(100, 100 - used)).rounded())
    }
}
