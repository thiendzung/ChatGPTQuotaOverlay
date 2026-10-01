import Foundation

enum QuotaFreshness: Equatable {
    case fresh
    case stale
    case unavailable
}

struct Quota: Equatable {
    let fiveHourPercent: Int?
    let weekPercent: Int?
    let freshness: QuotaFreshness

    init(
        fiveHourPercent: Int?,
        weekPercent: Int?,
        freshness: QuotaFreshness = .fresh
    ) {
        self.fiveHourPercent = fiveHourPercent
        self.weekPercent = weekPercent
        self.freshness = freshness
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
