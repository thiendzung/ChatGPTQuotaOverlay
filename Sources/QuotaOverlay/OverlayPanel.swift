import AppKit

private final class RingQuotaView: NSView {
    var onHover: (() -> Void)?
    var onHoverExit: (() -> Void)?
    var contextMenuProvider: (() -> NSMenu?)?

    var quota: Quota = .unavailable {
        didSet { needsDisplay = true }
    }

    private var trackingAreaRef: NSTrackingArea?

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
        onHover?()
    }

    override func mouseExited(with event: NSEvent) {
        onHoverExit?()
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        contextMenuProvider?()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let trackColor = NSColor.separatorColor.withAlphaComponent(0.34)

        drawRing(
            percent: quota.fiveHourPercent,
            center: center,
            radius: 19.0,
            lineWidth: 3.4,
            trackColor: trackColor,
            progressColor: .systemBlue
        )

        drawRing(
            percent: quota.weekPercent,
            center: center,
            radius: 14.0,
            lineWidth: 3.0,
            trackColor: trackColor,
            progressColor: .systemPurple
        )

        drawCenterValue(
            quota.fiveHourPercent.map(String.init) ?? "—",
            color: .systemBlue,
            y: center.y + 0.2
        )
        drawCenterValue(
            quota.weekPercent.map(String.init) ?? "—",
            color: .systemPurple,
            y: center.y - 8.2
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

    private func drawCenterValue(_ text: String, color: NSColor, y: CGFloat) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 7.8, weight: .semibold),
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]

        let rect = NSRect(x: bounds.midX - 11, y: y, width: 22, height: 9)
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
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        hidesOnDeactivate = false
        ignoresMouseEvents = true

        let container = NSView(frame: contentRect(forFrameRect: frame))
        container.wantsLayer = true
        container.layer?.cornerRadius = 7
        container.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.96).cgColor
        container.layer?.borderWidth = 0.5
        container.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.45).cgColor

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
    var onQuit: (() -> Void)?

    @objc func refresh(_ sender: Any?) { onRefresh?() }
    @objc func requestAccessibility(_ sender: Any?) { onRequestAccessibility?() }
    @objc func quit(_ sender: Any?) { onQuit?() }
}

final class OverlayPanel: NSPanel {
    var onHover: (() -> Void)?
    var onRefresh: (() -> Void)? {
        didSet { menuTarget.onRefresh = onRefresh }
    }
    var onRequestAccessibility: (() -> Void)? {
        didSet { menuTarget.onRequestAccessibility = onRequestAccessibility }
    }
    var onQuit: (() -> Void)? {
        didSet { menuTarget.onQuit = onQuit }
    }
    var accessibilityEnabledProvider: (() -> Bool)?

    private let ringView = RingQuotaView(frame: NSRect(x: 0, y: 0, width: 46, height: 46))
    private let tooltipPanel = QuotaTooltipPanel()
    private let menuTarget = MenuActionTarget()
    private var quota: Quota = .unavailable
    private var hoverWorkItem: DispatchWorkItem?

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 46, height: 46),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
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

    func update(quota: Quota) {
        self.quota = quota
        ringView.quota = quota
        tooltipPanel.update(text: quota == .unavailable ? "Real quota unavailable" : quota.hoverText)
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
        tooltipPanel.update(text: quota == .unavailable ? "Real quota unavailable" : quota.hoverText)
        positionTooltip()
        tooltipPanel.orderFrontRegardless()
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
            ? "Live window tracking: On"
            : "Enable live window tracking…"
        let accessibility = NSMenuItem(
            title: accessibilityTitle,
            action: accessibilityEnabled ? nil : #selector(MenuActionTarget.requestAccessibility(_:)),
            keyEquivalent: ""
        )
        accessibility.target = accessibilityEnabled ? nil : menuTarget
        accessibility.isEnabled = !accessibilityEnabled
        menu.addItem(accessibility)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit ChatGPT Quota Overlay", action: #selector(MenuActionTarget.quit(_:)), keyEquivalent: "")
        quit.target = menuTarget
        menu.addItem(quit)

        return menu
    }
}
