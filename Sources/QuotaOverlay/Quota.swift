import Foundation

struct Quota: Equatable {
    let fiveHourPercent: Int?
    let weekPercent: Int?

    var compactText: String {
        "\(display(fiveHourPercent))/\(display(weekPercent))%"
    }

    var hoverText: String {
        let five = fiveHourPercent.map { "\($0)%" } ?? "unavailable"
        let week = weekPercent.map { "\($0)%" } ?? "unavaile"
        return "5h \(five) · Week \(week)"
    }

    static let unavailable = Quota(fiveHourPercent: nil, weekPercent: nil)

    private func display(_ value: Int?) -> String {
        value.map(String.init) ?? "—"
    }
}
