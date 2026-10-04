import Foundation

enum QuotaFreshness: Equatable {
    case fresh
    case stale
    case unavailable
}

enum QuotaWindowKind: Equatable {
    case fiveHour
    case week

    var compactLabel: String {
        switch self {
        case .fiveHour: return "5h"
        case .week: return "W"
        }
    }

    var displayName: String {
        switch self {
        case .fiveHour: return "5-hour"
        case .week: return "Weekly"
        }
    }
}

struct QuotaBinding: Equatable {
    let kind: QuotaWindowKind
    let percent: Int
}

struct Quota: Equatable {
    let fiveHourPercent: Int?
    let weekPercent: Int?
    let fiveHourResetsAt: Date?
    let weekResetsAt: Date?
    let freshness: QuotaFreshness

    init(
        fiveHourPercent: Int?,
        weekPercent: Int?,
        fiveHourResetsAt: Date? = nil,
        weekResetsAt: Date? = nil,
        freshness: QuotaFreshness = .fresh
    ) {
        self.fiveHourPercent = fiveHourPercent
        self.weekPercent = weekPercent
        self.fiveHourResetsAt = fiveHourResetsAt
        self.weekResetsAt = weekResetsAt
        self.freshness = freshness
    }

    /// OpenAI requires allowance in every active window. The smallest remaining
    /// active window is therefore the most useful single number to show.
    var bindingLimit: QuotaBinding? {
        switch (fiveHourPercent, weekPercent) {
        case let (five?, week?):
            if week <= five {
                return QuotaBinding(kind: .week, percent: week)
            }
            return QuotaBinding(kind: .fiveHour, percent: five)
        case let (five?, nil):
            return QuotaBinding(kind: .fiveHour, percent: five)
        case let (nil, week?):
            return QuotaBinding(kind: .week, percent: week)
        case (nil, nil):
            return nil
        }
    }

    var statusBarText: String {
        guard freshness != .unavailable, let bindingLimit else {
            return "Q —"
        }
        let stalePrefix = freshness == .stale ? "~" : ""
        return "\(stalePrefix)\(bindingLimit.kind.compactLabel) \(bindingLimit.percent)%"
    }

    var compactText: String {
        "\(display(fiveHourPercent))/\(display(weekPercent))%"
    }

    var hoverText: String {
        let five = fiveHourPercent.map { "\($0)%" } ?? "unavailable"
        let week = weekPercent.map { "\($0)%" } ?? "unavailable"
        let suffix = freshness == .stale ? " · cached" : ""
        return "5h \(five) · Week \(week)\(suffix)"
    }

    var hasValues: Bool {
        fiveHourPercent != nil || weekPercent != nil
    }

    func markedStale() -> Quota {
        guard hasValues else { return .unavailable }
        return Quota(
            fiveHourPercent: fiveHourPercent,
            weekPercent: weekPercent,
            fiveHourResetsAt: fiveHourResetsAt,
            weekResetsAt: weekResetsAt,
            freshness: .stale
        )
    }

    static let unavailable = Quota(
        fiveHourPercent: nil,
        weekPercent: nil,
        freshness: .unavailable
    )

    private func display(_ value: Int?) -> String {
        value.map(String.init) ?? "—"
    }
}
