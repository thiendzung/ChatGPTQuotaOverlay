import XCTest
@testable import QuotaOverlay

final class QuotaDisplayTests: XCTestCase {
    func testWeeklyBecomesBindingLimitWhenLower() {
        let quota = Quota(fiveHourPercent: 78, weekPercent: 6)

        XCTAssertEqual(
            quota.bindingLimit,
            QuotaBinding(kind: .week, percent: 6)
        )
        XCTAssertEqual(quota.statusBarText, "W 6%")
        XCTAssertEqual(quota.hoverText, "5h 78% · Week 6%")
    }

    func testFiveHourBecomesBindingLimitWhenLower() {
        let quota = Quota(fiveHourPercent: 12, weekPercent: 70)

        XCTAssertEqual(
            quota.bindingLimit,
            QuotaBinding(kind: .fiveHour, percent: 12)
        )
        XCTAssertEqual(quota.statusBarText, "5h 12%")
    }

    func testSingleWeeklyWindowDoesNotInventFiveHourLimit() {
        let quota = Quota(fiveHourPercent: nil, weekPercent: 55)

        XCTAssertEqual(
            quota.bindingLimit,
            QuotaBinding(kind: .week, percent: 55)
        )
        XCTAssertEqual(quota.statusBarText, "W 55%")
        XCTAssertEqual(quota.hoverText, "5h unavailable · Week 55%")
    }

    func testStaleQuotaIsExplicit() {
        let quota = Quota(fiveHourPercent: 80, weekPercent: 40).markedStale()

        XCTAssertEqual(quota.statusBarText, "~W 40%")
        XCTAssertTrue(quota.hoverText.contains("cached"))
    }

    func testUnavailableQuotaIsMinimal() {
        XCTAssertEqual(Quota.unavailable.statusBarText, "—")
    }
}
