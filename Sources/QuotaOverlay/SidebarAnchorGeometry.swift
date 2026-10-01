import CoreGraphics

/// Stable geometry for placing the quota widget in ChatGPT's compact left rail.
///
/// We deliberately anchor to the avatar *zone* rather than traversing ChatGPT's
/// accessibility tree to find the profile control itself. This keeps the
/// permission scope narrow and makes the integration less brittle when ChatGPT
/// changes internal UI structure.
enum SidebarAnchorGeometry {
    /// Center of ChatGPT's compact icon rail, measured from the window's left edge.
    static let railCenterX: CGFloat = 27

    /// Approximate center of the profile avatar, measured from the window bottom.
    static let avatarCenterFromBottom: CGFloat = 26

    /// Vertical distance from the avatar center to the quota widget center.
    static let quotaCenterAboveAvatar: CGFloat = 51

    static func quotaFrame(
        chatGPTFrame: CGRect,
        quotaSize: CGFloat
    ) -> CGRect {
        let centerX = chatGPTFrame.minX + railCenterX
        let centerY = chatGPTFrame.minY
            + avatarCenterFromBottom
            + quotaCenterAboveAvatar

        return CGRect(
            x: centerX - quotaSize / 2,
            y: centerY - quotaSize / 2,
            width: quotaSize,
            height: quotaSize
        )
    }
}
