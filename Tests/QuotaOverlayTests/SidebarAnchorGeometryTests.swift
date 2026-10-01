import CoreGraphics
import XCTest
@testable import QuotaOverlay

final class SidebarAnchorGeometryTests: XCTestCase {
    func testQuotaFrameStaysAnchoredToAvatarZone() {
        let chatGPTFrame = CGRect(x: 100, y: 200, width: 900, height: 700)

        let frame = SidebarAnchorGeometry.quotaFrame(
            chatGPTFrame: chatGPTFrame,
            quotaSize: 40
        )

        XCTAssertEqual(frame.origin.x, 107, accuracy: 0.001)
        XCTAssertEqual(frame.origin.y, 257, accuracy: 0.001)
        XCTAssertEqual(frame.width, 40, accuracy: 0.001)
        XCTAssertEqual(frame.height, 40, accuracy: 0.001)
    }

    func testResizeKeepsAvatarZoneAnchorStable() {
        let compact = SidebarAnchorGeometry.quotaFrame(
            chatGPTFrame: CGRect(x: 50, y: 80, width: 800, height: 600),
            quotaSize: 40
        )
        let resized = SidebarAnchorGeometry.quotaFrame(
            chatGPTFrame: CGRect(x: 50, y: 80, width: 1300, height: 950),
            quotaSize: 40
        )

        XCTAssertEqual(compact, resized)
    }

    func testMovingChatGPTMovesQuotaByExactlySameDelta() {
        let first = SidebarAnchorGeometry.quotaFrame(
            chatGPTFrame: CGRect(x: 50, y: 80, width: 900, height: 700),
            quotaSize: 40
        )
        let second = SidebarAnchorGeometry.quotaFrame(
            chatGPTFrame: CGRect(x: 173, y: 127, width: 900, height: 700),
            quotaSize: 40
        )

        XCTAssertEqual(second.origin.x - first.origin.x, 123, accuracy: 0.001)
        XCTAssertEqual(second.origin.y - first.origin.y, 47, accuracy: 0.001)
    }
}
