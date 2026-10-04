import XCTest
@testable import QuotaOverlay

final class QuotaParserTests: XCTestCase {
    func testRealWorldFiveHourAndWeeklyQuota() throws {
        let response: [String: Any] = [
            "rateLimitsByLimitId": [
                "codex": [
                    "limitId": "codex",
                    "primary": [
                        "usedPercent": 38,
                        "windowDurationMins": 300,
                        "resetsAt": 1_790_836_859
                    ],
                    "secondary": [
                        "usedPercent": 45,
                        "windowDurationMins": 10080,
                        "resetsAt": 1_791_012_827
                    ]
                ]
            ]
        ]

        let quota = try XCTUnwrap(QuotaParser.quota(fromRateLimitsResponse: response))
        XCTAssertEqual(quota.fiveHourPercent, 62)
        XCTAssertEqual(quota.weekPercent, 55)
        XCTAssertEqual(
            try XCTUnwrap(quota.fiveHourResetsAt).timeIntervalSince1970,
            1_790_836_859,
            accuracy: 0.5
        )
        XCTAssertEqual(
            try XCTUnwrap(quota.weekResetsAt).timeIntervalSince1970,
            1_791_012_827,
            accuracy: 0.5
        )
    }

    func testWindowOrderDoesNotMatter() throws {
        let snapshot: [String: Any] = [
            "primary": ["usedPercent": 20, "windowDurationMins": 10080],
            "secondary": ["usedPercent": 70, "windowDurationMins": 300]
        ]

        let quota = try XCTUnwrap(QuotaParser.quota(fromSnapshot: snapshot))
        XCTAssertEqual(quota.fiveHourPercent, 30)
        XCTAssertEqual(quota.weekPercent, 80)
    }

    func testSparseUpdatePreservesOtherWindow() throws {
        let base: [String: Any] = [
            "limitId": "codex",
            "primary": ["usedPercent": 38, "windowDurationMins": 300],
            "secondary": ["usedPercent": 45, "windowDurationMins": 10080]
        ]
        let update: [String: Any] = [
            "limitId": "codex",
            "primary": ["usedPercent": 50, "windowDurationMins": 300]
        ]

        let merged = QuotaParser.mergeSnapshot(base: base, update: update)
        let quota = try XCTUnwrap(QuotaParser.quota(fromSnapshot: merged))
        XCTAssertEqual(quota.fiveHourPercent, 50)
        XCTAssertEqual(quota.weekPercent, 55)
    }

    func testRemainingPercentIsClamped() throws {
        let snapshot: [String: Any] = [
            "primary": ["usedPercent": 120, "windowDurationMins": 300],
            "secondary": ["usedPercent": -5, "windowDurationMins": 10080]
        ]

        let quota = try XCTUnwrap(QuotaParser.quota(fromSnapshot: snapshot))
        XCTAssertEqual(quota.fiveHourPercent, 0)
        XCTAssertEqual(quota.weekPercent, 100)
    }

    func testParsedQuotaStartsFreshAndCanBecomeStale() throws {
        let snapshot: [String: Any] = [
            "primary": ["usedPercent": 38, "windowDurationMins": 300],
            "secondary": ["usedPercent": 45, "windowDurationMins": 10080]
        ]

        let quota = try XCTUnwrap(QuotaParser.quota(fromSnapshot: snapshot))
        XCTAssertEqual(quota.freshness, .fresh)
        XCTAssertEqual(quota.fiveHourPercent, 62)
        XCTAssertEqual(quota.weekPercent, 55)

        let stale = quota.markedStale()
        XCTAssertEqual(stale.freshness, .stale)
        XCTAssertEqual(stale.fiveHourPercent, 62)
        XCTAssertEqual(stale.weekPercent, 55)
        XCTAssertTrue(stale.hoverText.contains("cached"))
    }

    func testUnavailableQuotaCannotPretendToBeStale() {
        XCTAssertEqual(Quota.unavailable.markedStale(), .unavailable)
        XCTAssertEqual(Quota.unavailable.freshness, .unavailable)
    }

}
