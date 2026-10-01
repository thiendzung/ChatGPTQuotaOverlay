import AppKit

private enum OverlayMetrics {
    static let size: CGFloat = 40
    static let outerRadius: CGFloat = 16.4
    static let innerRadius: CGFloat = 11.7
    static let outerLineWidth: CGFloat = 2.5
    static let innerLineWidth: CGFloat = 2.1
}

private final class RingQuotaView: NSView {
    var onHover: (() -> Void)?
    var onHoverExit: (() -> Void)?
    var contextMenuProvider: (() -> NSMenu?)?

    var quota: Quota = .unavailable {
        didSet { needsDisplay = true }
    }

    private var trackingAreaRef: NSTrackingArea?
    private var isHovered = false

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingAreaRef {
            removeTrackingArea(trackingAreaRef)
        }

        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingAreaRef = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        needsDisplay = true
        onHover?()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        needsDisplay = true
        onHoverExit?()
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        contextMenuProvider?()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let center = NSPoint(x: bounds.midX, y: bounds.midY)

        if isHovered {
            let hoverRect = NSRect(
                x: center.x - 19,
                y: center.y - 19,
                width: 38,
                height: 38
            )
            NSColor.labelColor.withAlphaComponent(0.045).setFill()
            NSBezierPath(ovalIn: hoverRect).fill()
        }

        // Stale values remain readable but intentionally look cached rather than live.
        let freshnessAlpha: CGFloat = quota.freshness == .stale ? 0.42 : 1.0
        let trackColor = NSColor.secondaryLabelColor.withAlphaComponent(0.17 * freshnessAlpha)

        drawRing(
            percent: quota.fiveHourPercent,
            center: center,
            radius: OverlayMetrics.outerRadius,
            lineWidth: OverlayMetrics.outerLineWidth,
            trackColor: trackColor,
            progressColor: NSColor.systemBlue.withAlphaComponent(0.96 * freshnessAlpha)
        )

        drawRing(
            percent: quota.weekPercent,
            center: center,
            radius: OverlayMetrics.innerRadius,
            lineWidth: OverlayMetrics.innerLineWidth,
            trackColor: trackColor,
            progressColor: NSColor.systemPurple.withAlphaComponent(0.92 * freshnessAlpha)
        )

        drawCenterValue(
            quota.fiveHourPercent.map(String.init) ?? "—",
            fontSize: 10.2,
            weight: .bold,
            y: center.y + 0.15,
            alpha: quota.freshness == .stale ? 0.52 : 0.96
        )
        drawCenterValue(
            quota.weekPercent.map(String.init) ?? "—",
            fontSize: 9.6,
            weight: .semibold,
            y: center.y - 9.65,
            alpha: quota.freshness == .stale ? 0.52 : 0.96
        )
    }

    private func drawRing(
        percent: Int?,
        center: NSPoint,
        radius: CGFloat,
        lineWidth: CGFloat,
        trackColor: NSColor,
        progressColor: NSColor
    ) {
        let track = NSBezierPath()
        track.appendArc(
            withCenter: center,
            radius: radius,
            startAngle: 90,
            endAngle: -270,
            clockwise: true
        )
        track.lineWidth = lineWidth
        track.lineCapStyle = .round
        trackColor.setStroke()
        track.stroke()

        guard let percent else { return }
        let clamped = max(0, min(100, percent))
        guard clamped > 0 else { return }

        let endAngle = 90.0 - (360.0 * CGFloat(clamped) / 100.0)
        let progress = NSBezierPath()
        progress.appendArc(
            withCenter: center,
            radius: radius,
            startAngle: 90,
            endAngle: endAngle,
            clockwise: true
        )
        progress.lineWidth = lineWidth
        progress.lineCapStyle = .round
        progressColor.setStroke()
        progress.stroke()
    }

    private func drawCenterValue(
        _ text: String,
        fontSize: CGFloat,
        weight: NSFont.Weight,
        y: CGFloat,
        alpha: CGFloat
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: weight),
            .foregroundColor: NSColor.labelColor.withAlphaComponent(alpha),
            .paragraphStyle: paragraph
        ]

        let rect = NSRect(x: bounds.midX - 12, y: y, width: 24, height: 11)
        (text as NSString).draw(in: rect, withAttributes: attributes)
    }
}

private final class QuotaTooltipPanel: NSPanel {
    private let label = NSTextField(labelWithString: "5h — · Week —")

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 142, height: 28),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .normal
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        hidesOnDeactivate = false
        ignoresMouseEvents = true

        let container = NSView(frame: contentRect(forFrameRect: frame))
        container.wantsLayer = true
        container.layer?.cornerRadius = 7
        container.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.97).cgColor
        container.layer?.borderWidth = 0.5
        container.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.35).cgColor

        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = NSFont.monospacedDigitSystemFont(ofSize: 11.5, weight: .medium)
        label.textColor = .labelColor
        label.alignment = .center
        label.lineBreakMode = .byClipping

        container.addSubview(label)
        contentView = container

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 9),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -9),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
    }

    func update(text: String) {
        label.stringValue = text
        let width = max(142, label.intrinsicContentSize.width + 20)
        setContentSize(NSSize(width: width, height: 28))
    }
}

private final class MenuActionTarget: NSObject {
    var onRefresh: (() -> Void)?
    var onRequestAccessibility: (() -> Void)?
    var onToggleLaunchAtLogin: (() -> Void)?
    var onOpenLoginItemsSettings: (() -> Void)?
    var onQuit: (() -> Void)?

    @objc func refresh(_ sender: Any?) { onRefresh?() }
    @objc func requestAccessibility(_ sender: Any?) { onRequestAccessibility?() }
    @objc func toggleLaunchAtLogin(_ sender: Any?) { onToggleLaunchAtLogin?() }
    @objc func openLoginItemsSettings(_ sender: Any?) { onOpenLoginItemsSettings?() }
    @objc func quit(_ sender: Any?) { onQuit?() }
}

final class OverlayPanel: NSPanel {
    static let preferredSize = NSSize(width: OverlayMetrics.size, height: OverlayMetrics.size)

    var onHover: (() -> Void)?
    var onRefresh: (() -> Void)? {
        didSet { menuTarget.onRefresh = onRefresh }
    }
    var onRequestAccessibility: (() -> Void)? {
        didSet { menuTarget.onRequestAccessibility = onRequestAccessibility }
    }
    var onToggleLaunchAtLogin: (() -> Void)? {
        didSet { menuTarget.onToggleLaunchAtLogin = onToggleLaunchAtLogin }
    }
    var onOpenLoginItemsSettings: (() -> Void)? {
        didSet { menuTarget.onOpenLoginItemsSettings = onOpenLoginItemsSettings }
    }
    var onQuit: (() -> Void)? {
        didSet { menuTarget.onQuit = onQuit }
    }
    var accessibilityEnabledProvider: (() -> Bool)?
    var launchAtLoginStateProvider: (() -> LaunchAtLoginState)?

    private let ringView = RingQuotaView(
        frame: NSRect(origin: .zero, size: OverlayPanel.preferredSize)
    )
    private let tooltipPanel = QuotaTooltipPanel()
    private let menuTarget = MenuActionTarget()
    private var quota: Quota = .unavailable
    private var hoverWorkItem: DispatchWorkItem?

    init() {
        super.init(
            contentRect: NSRect(origin: .zero, size: OverlayPanel.preferredSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .normal
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        hidesOnDeactivate = false
        ignoresMouseEvents = false

        ringView.autoresizingMask = [.width, .height]
        ringView.frame = contentRect(forFrameRect: frame)
        ringView.onHover = { [weak self] in self?.handleMouseEnter() }
        ringView.onHoverExit = { [weak self] in self?.handleMouseExit() }
        ringView.contextMenuProvider = { [weak self] in self?.makeContextMenu() }
        contentView = ringView
    }

    override func orderOut(_ sender: Any?) {
        hideTooltip()
        super.orderOut(sender)
    }

    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        super.setFrame(frameRect, display: flag)
        if tooltipPanel.isVisible {
            positionTooltip()
        }
    }

    /// Keep the overlay immediately above the target ChatGPT window in the
    /// WindowServer z-order instead of changing levels when app focus changes.
    /// This prevents the panel from sinking behind ChatGPT on deactivation,
    /// while a newly active application can still remain above both windows.
    func present(
        aboveChatGPTWindowID windowID: CGWindowID,
        isChatGPTActive: Bool
    ) {
        guard windowID != kCGNullWindowID else {
            orderOut(nil)
            return
        }

        level = .normal
        tooltipPanel.level = .normal

        if isChatGPTActive {
            // ChatGPT is already the active app, so bringing this normal-level
            // nonactivating panel to the front cannot cover another app.
            // This also guarantees reappearance after either app is relaunched.
            orderFrontRegardless()
        } else {
            // Once another app becomes active, put the overlay immediately above
            // ChatGPT in WindowServer order. The active app remains above both.
            order(.above, relativeTo: Int(windowID))
        }
    }

    func update(quota: Quota) {
        self.quota = quota
        ringView.quota = quota
        tooltipPanel.update(text: quota.freshness == .unavailable ? "Real quota unavailable" : quota.hoverText)
    }

    private func handleMouseEnter() {
        onHover?()
        hoverWorkItem?.cancel()

        let item = DispatchWorkItem { [weak self] in self?.showTooltip() }
        hoverWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16, execute: item)
    }

    private func handleMouseExit() {
        hoverWorkItem?.cancel()
        hoverWorkItem = nil
        hideTooltip()
    }

    private func showTooltip() {
        guard isVisible else { return }
        tooltipPanel.update(text: quota.freshness == .unavailable ? "Real quota unavailable" : quota.hoverText)
        positionTooltip()
        tooltipPanel.level = .normal

        // Keep the tooltip immediately above our own panel instead of forcing
        // it above the active application.
        if windowNumber > 0 {
            tooltipPanel.order(.above, relativeTo: windowNumber)
        } else {
            tooltipPanel.orderFront(nil)
        }
    }

    private func hideTooltip() {
        hoverWorkItem?.cancel()
        hoverWorkItem = nil
        tooltipPanel.orderOut(nil)
    }

    private func positionTooltip() {
        guard let screen = screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = tooltipPanel.frame.size

        var x = frame.maxX + 8
        var y = frame.midY - size.height / 2

        if x + size.width > visible.maxX - 6 {
            x = frame.minX - size.width - 8
        }
        y = min(max(y, visible.minY + 6), visible.maxY - size.height - 6)

        tooltipPanel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func makeContextMenu() -> NSMenu {
        let menu = NSMenu(title: "ChatGPT Quota Overlay")

        let refresh = NSMenuItem(title: "Refresh quota now", action: #selector(MenuActionTarget.refresh(_:)), keyEquivalent: "")
        refresh.target = menuTarget
        menu.addItem(refresh)

        let accessibilityEnabled = accessibilityEnabledProvider?() ?? false
        let accessibilityTitle = accessibilityEnabled
            ? "Live tracking: On"
            : "Live tracking: Off — Enable…"
        let accessibility = NSMenuItem(
            title: accessibilityTitle,
            action: accessibilityEnabled ? nil : #selector(MenuActionTarget.requestAccessibility(_:)),
            keyEquivalent: ""
        )
        accessibility.target = accessibilityEnabled ? nil : menuTarget
        accessibility.isEnabled = !accessibilityEnabled
        menu.addItem(accessibility)

        if !accessibilityEnabled {
            let explanation = NSMenuItem(
                title: "Realtime window dragging requires Accessibility",
                action: nil,
                keyEquivalent: ""
            )
            explanation.isEnabled = false
            menu.addItem(explanation)
        }

        let launchState = launchAtLoginStateProvider?() ?? .unavailable
        switch launchState {
        case .off, .on:
            let launch = NSMenuItem(
                title: "Start at Login",
                action: #selector(MenuActionTarget.toggleLaunchAtLogin(_:)),
                keyEquivalent: ""
            )
            launch.target = menuTarget
            launch.state = launchState == .on ? .on : .off
            menu.addItem(launch)
        case .requiresApproval:
            let launch = NSMenuItem(
                title: "Start at Login: Needs approval…",
                action: #selector(MenuActionTarget.openLoginItemsSettings(_:)),
                keyEquivalent: ""
            )
            launch.target = menuTarget
            menu.addItem(launch)
        case .unavailable:
            let launch = NSMenuItem(title: "Start at Login: Unavailable", action: nil, keyEquivalent: "")
            launch.isEnabled = false
            menu.addItem(launch)
        }

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit ChatGPT Quota Overlay", action: #selector(MenuActionTarget.quit(_:)), keyEquivalent: "")
        quit.target = menuTarget
        menu.addItem(quit)

        return menu
    }
}
