import AppKit
import QuartzCore

final class FriendsTabView: DSTabView {

    // Layout constants
    private static let panelW: CGFloat = 580
    private static let contentH: CGFloat = 430

    // Colors
    private static let bgTop = NSColor(red: 0x2D/255.0, green: 0x5B/255.0, blue: 0x8E/255.0, alpha: 1)
    private static let bgBot = NSColor(red: 0x1A/255.0, green: 0x3B/255.0, blue: 0x6A/255.0, alpha: 1)
    private static let sectionBg = NSColor(white: 0.0, alpha: 0.25)

    // State
    private var friendCode: String? = nil
    private var friends: [(id: String, name: String, code: String)] = []
    private var pendingRequests: [(id: String, fromName: String)] = []
    private var messageText: String? = nil
    private var messageTimer: Timer? = nil

    // Text field for friend code input
    private var codeInputField: NSTextField?

    // Scroll view for friends list
    private var scrollView: NSScrollView?

    init() {
        super.init(backgroundColor: FriendsTabView.bgTop)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }

    override var disableHoverTracking: Bool { true }

    // Let the text field receive clicks for typing
    override func hitTest(_ point: NSPoint) -> NSView? {
        // The text field is nested inside a section container, so we need to
        // walk the view hierarchy to find it
        if let field = codeInputField {
            // Convert point from self to the field's coordinate space
            // field is inside addSection which is inside self
            if let fieldSuper = field.superview {
                let inParent = fieldSuper.convert(point, from: self)
                let inField = field.convert(inParent, from: fieldSuper)
                if field.bounds.contains(inField) {
                    // Make the field first responder so it accepts typing
                    window?.makeFirstResponder(field)
                    return field
                }
            }
        }
        return super.hitTest(point)
    }

    override func layout() {
        super.layout()
        if let grad = layer?.sublayers?.first(where: { $0.name == "friendsBgGrad" }) as? CAGradientLayer {
            grad.frame = bounds
        }
    }

    // MARK: - External Data Setters

    func setFriendCode(_ code: String) {
        friendCode = code
        rebuildUI()
    }

    func setFriends(_ friends: [(id: String, name: String, code: String)]) {
        self.friends = friends
        rebuildUI()
    }

    func setPendingRequests(_ requests: [(id: String, fromName: String)]) {
        self.pendingRequests = requests
        rebuildUI()
    }

    func showMessage(_ text: String) {
        messageText = text
        rebuildUI()
        messageTimer?.invalidate()
        messageTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            self?.messageText = nil
            self?.rebuildUI()
        }
    }

    // MARK: - Update (from DSTab protocol)

    override func update(state: PetState) {
        rebuildUI()
    }

    // MARK: - Rebuild

    private func rebuildUI() {
        // Preserve text field content across rebuilds
        let savedText = codeInputField?.stringValue ?? ""
        subviews.forEach { $0.removeFromSuperview() }
        layer?.sublayers?.removeAll(where: { $0.name == "friendsBgGrad" })
        clearHitRegions()
        codeInputField = nil
        scrollView = nil

        // Background gradient
        let bgGrad = CAGradientLayer()
        bgGrad.name = "friendsBgGrad"
        bgGrad.frame = bounds
        bgGrad.colors = [FriendsTabView.bgTop.cgColor, FriendsTabView.bgBot.cgColor]
        bgGrad.startPoint = CGPoint(x: 0.5, y: 0)
        bgGrad.endPoint = CGPoint(x: 0.5, y: 1)
        layer?.insertSublayer(bgGrad, at: 0)

        let pad = DS.outerPad
        let usableW = Self.panelW - pad * 2
        var cursorY: CGFloat = pad

        // --- Message banner (if any) ---
        if let msg = messageText {
            let bannerH: CGFloat = 28
            let banner = NSView(frame: NSRect(x: pad, y: cursorY, width: usableW, height: bannerH))
            banner.wantsLayer = true
            banner.layer?.cornerRadius = 6
            banner.layer?.backgroundColor = DS.cardGreenTop.withAlphaComponent(0.8).cgColor

            let msgLabel = DS.label(msg, size: 11, bold: true)
            msgLabel.translatesAutoresizingMaskIntoConstraints = true
            msgLabel.alignment = .center
            msgLabel.frame = NSRect(x: 0, y: 4, width: usableW, height: 20)
            banner.addSubview(msgLabel)
            addSubview(banner)
            cursorY += bannerH + 8
        }

        // --- Your Friend Code ---
        let codeSectionH: CGFloat = 56
        let codeSection = makeSection(x: pad, y: cursorY, w: usableW, h: codeSectionH)
        addSubview(codeSection)

        let codeTitle = DS.label("Your Code", size: 10, bold: false, color: DS.textSecondary)
        codeTitle.translatesAutoresizingMaskIntoConstraints = true
        codeTitle.frame = NSRect(x: 10, y: 6, width: usableW - 20, height: 14)
        codeSection.addSubview(codeTitle)

        let displayCode = friendCode ?? "Loading..."
        let codeLabel = NSTextField(labelWithString: displayCode)
        codeLabel.font = NSFont.monospacedSystemFont(ofSize: 22, weight: .bold)
        codeLabel.textColor = DS.gold
        codeLabel.drawsBackground = false
        codeLabel.isBordered = false
        codeLabel.isEditable = false
        codeLabel.isSelectable = true
        codeLabel.shadow = DS.dsShadow()
        codeLabel.alignment = .center
        codeLabel.frame = NSRect(x: 10, y: 24, width: usableW - 20, height: 28)
        codeSection.addSubview(codeLabel)

        cursorY += codeSectionH + DS.cardGap

        // --- Add Friend ---
        let addSectionH: CGFloat = 48
        let addSection = makeSection(x: pad, y: cursorY, w: usableW, h: addSectionH)
        addSubview(addSection)

        let addTitle = DS.label("Add Friend", size: 10, bold: false, color: DS.textSecondary)
        addTitle.translatesAutoresizingMaskIntoConstraints = true
        addTitle.frame = NSRect(x: 10, y: 6, width: 80, height: 14)
        addSection.addSubview(addTitle)

        let fieldW: CGFloat = 120
        let fieldH: CGFloat = 24
        let fieldX: CGFloat = (usableW - fieldW - 60 - 8) / 2
        let fieldY: CGFloat = 18

        let field = NSTextField(frame: NSRect(x: fieldX, y: fieldY, width: fieldW, height: fieldH))
        field.placeholderString = "Code"
        field.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .bold)
        field.alignment = .center
        field.bezelStyle = .roundedBezel
        field.focusRingType = .none
        addSection.addSubview(field)
        codeInputField = field
        field.stringValue = savedText

        // "Add" button
        let btnW: CGFloat = 60
        let btnH: CGFloat = 24
        let btnX = fieldX + fieldW + 8
        let btnY = fieldY
        let addBtn = makeButton(label: "Add", frame: NSRect(x: btnX, y: btnY, width: btnW, height: btnH), in: addSection)
        addSection.addSubview(addBtn)

        // Hit region for Add button (in parent view coordinates)
        let addBtnInParent = NSRect(
            x: pad + btnX,
            y: cursorY + btnY,
            width: btnW,
            height: btnH
        )
        addHitRegion(HitRegion(
            id: "add_friend",
            rect: addBtnInParent,
            action: .addFriend(code: "")  // placeholder -- actual code read in mouseDown override
        ))

        cursorY += addSectionH + DS.cardGap

        // --- Pending Requests (if any) ---
        if !pendingRequests.isEmpty {
            let rowH: CGFloat = 32
            let headerH: CGFloat = 20
            let requestsSectionH = headerH + CGFloat(pendingRequests.count) * rowH + 8
            let requestsSection = makeSection(x: pad, y: cursorY, w: usableW, h: requestsSectionH)
            addSubview(requestsSection)

            let reqTitle = DS.label("Pending Requests", size: 10, bold: false, color: DS.textSecondary)
            reqTitle.translatesAutoresizingMaskIntoConstraints = true
            reqTitle.frame = NSRect(x: 10, y: 4, width: usableW - 20, height: 14)
            requestsSection.addSubview(reqTitle)

            for (i, request) in pendingRequests.enumerated() {
                let rowY = headerH + CGFloat(i) * rowH
                let nameLabel = DS.label(request.fromName, size: 12, bold: true)
                nameLabel.translatesAutoresizingMaskIntoConstraints = true
                nameLabel.frame = NSRect(x: 14, y: rowY + 6, width: usableW - 100, height: 20)
                requestsSection.addSubview(nameLabel)

                let acceptW: CGFloat = 64
                let acceptH: CGFloat = 22
                let acceptX = usableW - acceptW - 14
                let acceptY = rowY + 5
                let acceptBtn = makeButton(label: "Accept", frame: NSRect(x: acceptX, y: acceptY, width: acceptW, height: acceptH), in: requestsSection)
                requestsSection.addSubview(acceptBtn)

                let acceptInParent = NSRect(
                    x: pad + acceptX,
                    y: cursorY + acceptY,
                    width: acceptW,
                    height: acceptH
                )
                addHitRegion(HitRegion(
                    id: "accept_\(request.id)",
                    rect: acceptInParent,
                    action: .acceptFriendRequest(requestId: request.id)
                ))
            }

            cursorY += requestsSectionH + DS.cardGap
        }

        // --- Friends List ---
        let friendsHeaderH: CGFloat = 20
        let remainingH = Self.contentH - cursorY - 8
        let friendsSectionH = max(remainingH, 80)
        let friendsSection = makeSection(x: pad, y: cursorY, w: usableW, h: friendsSectionH)
        addSubview(friendsSection)

        let friendsTitle = DS.label("Friends", size: 10, bold: false, color: DS.textSecondary)
        friendsTitle.translatesAutoresizingMaskIntoConstraints = true
        friendsTitle.frame = NSRect(x: 10, y: 4, width: usableW - 20, height: 14)
        friendsSection.addSubview(friendsTitle)

        if friends.isEmpty {
            let emptyLabel = DS.label("No friends yet. Share your code!", size: 12, bold: false, color: DS.textSecondary)
            emptyLabel.translatesAutoresizingMaskIntoConstraints = true
            emptyLabel.alignment = .center
            emptyLabel.frame = NSRect(x: 10, y: friendsSectionH / 2 - 10, width: usableW - 20, height: 20)
            friendsSection.addSubview(emptyLabel)
        } else {
            let scrollAreaY = friendsHeaderH + 4
            let scrollAreaH = friendsSectionH - scrollAreaY - 4

            let scroll = NSScrollView(frame: NSRect(x: 4, y: scrollAreaY, width: usableW - 8, height: scrollAreaH))
            scroll.hasVerticalScroller = true
            scroll.hasHorizontalScroller = false
            scroll.drawsBackground = false
            scroll.borderType = .noBorder
            scroll.scrollerStyle = .overlay

            let clipView = NSClipView()
            clipView.drawsBackground = false
            scroll.contentView = clipView

            let rowH: CGFloat = 40
            let docH = CGFloat(friends.count) * rowH
            let docView = FlippedView(frame: NSRect(x: 0, y: 0, width: usableW - 8, height: max(docH, scrollAreaH)))
            docView.wantsLayer = true

            for (i, friend) in friends.enumerated() {
                let rowY = CGFloat(i) * rowH
                let rowW = usableW - 8

                // Alternating row background
                if i % 2 == 0 {
                    let rowBg = NSView(frame: NSRect(x: 0, y: rowY, width: rowW, height: rowH))
                    rowBg.wantsLayer = true
                    rowBg.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.05).cgColor
                    docView.addSubview(rowBg)
                }

                // Friend name
                let nameLabel = DS.label(friend.name, size: 12, bold: true)
                nameLabel.translatesAutoresizingMaskIntoConstraints = true
                nameLabel.frame = NSRect(x: 10, y: rowY + 4, width: rowW - 110, height: 16)
                docView.addSubview(nameLabel)

                // Friend code
                let codeDisplay = DS.label(friend.code, size: 9, bold: false, color: DS.textSecondary)
                codeDisplay.translatesAutoresizingMaskIntoConstraints = true
                codeDisplay.font = NSFont.monospacedSystemFont(ofSize: 9, weight: .regular)
                codeDisplay.frame = NSRect(x: 10, y: rowY + 22, width: rowW - 110, height: 14)
                docView.addSubview(codeDisplay)

                // Send Gift button
                let giftW: CGFloat = 90
                let giftH: CGFloat = 24
                let giftX = rowW - giftW - 10
                let giftY = rowY + (rowH - giftH) / 2

                let giftBtn = NSView(frame: NSRect(x: giftX, y: giftY, width: giftW, height: giftH))
                giftBtn.wantsLayer = true
                giftBtn.layer?.cornerRadius = 6

                let giftGrad = CAGradientLayer()
                giftGrad.frame = CGRect(origin: .zero, size: CGSize(width: giftW, height: giftH))
                giftGrad.colors = [DS.cardGreenTop.cgColor, DS.cardGreenBot.cgColor]
                giftGrad.startPoint = CGPoint(x: 0.5, y: 0)
                giftGrad.endPoint = CGPoint(x: 0.5, y: 1)
                giftGrad.cornerRadius = 6
                giftBtn.layer?.addSublayer(giftGrad)

                let giftLabel = DS.label("Send Gift", size: 10, bold: true)
                giftLabel.translatesAutoresizingMaskIntoConstraints = true
                giftLabel.alignment = .center
                giftLabel.frame = NSRect(x: 0, y: 3, width: giftW, height: 18)
                giftBtn.addSubview(giftLabel)
                docView.addSubview(giftBtn)

                // Hit region for gift button (in parent view coordinates)
                // We need the offset from the scroll view's position in the parent
                let giftInParent = NSRect(
                    x: pad + 4 + giftX,
                    y: cursorY + scrollAreaY + giftY - (scroll.contentView.bounds.origin.y),
                    width: giftW,
                    height: giftH
                )
                addHitRegion(HitRegion(
                    id: "gift_\(friend.id)",
                    rect: giftInParent,
                    action: .sendGift(friendId: friend.id)
                ))
            }

            scroll.documentView = docView
            friendsSection.addSubview(scroll)
            scrollView = scroll
        }
    }

    // MARK: - Mouse Handling

    override func mouseDown(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)

        // Check if the add_friend region was hit -- read the actual text field value
        for region in hitRegions where region.enabled {
            if region.rect.contains(loc) {
                if region.id == "add_friend" {
                    let code = codeInputField?.stringValue.trimmingCharacters(in: .whitespaces) ?? ""
                    guard !code.isEmpty else { return }
                    onAction?(.addFriend(code: code))
                    codeInputField?.stringValue = ""
                    return
                }
                // For gift buttons inside scroll view, adjust hit test
                if region.id.hasPrefix("gift_"), let sv = scrollView {
                    let scrollOffset = sv.contentView.bounds.origin.y
                    var adjustedRect = region.rect
                    adjustedRect.origin.y -= scrollOffset
                    if adjustedRect.contains(loc) {
                        flashRegionManual(adjustedRect)
                        onAction?(region.action)
                        return
                    }
                } else {
                    flashRegionManual(region.rect)
                    onAction?(region.action)
                    return
                }
            }
        }
    }

    private func flashRegionManual(_ rect: NSRect) {
        let flash = CAShapeLayer()
        flash.path = CGPath(roundedRect: rect, cornerWidth: 6, cornerHeight: 6, transform: nil)
        flash.fillColor = NSColor.white.withAlphaComponent(0.3).cgColor
        layer?.addSublayer(flash)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            flash.removeFromSuperlayer()
        }
    }

    // MARK: - Helpers

    private func makeSection(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) -> NSView {
        let section = NSView(frame: NSRect(x: x, y: y, width: w, height: h))
        section.wantsLayer = true
        section.layer?.cornerRadius = DS.cardRadius
        section.layer?.backgroundColor = FriendsTabView.sectionBg.cgColor
        return section
    }

    private func makeButton(label text: String, frame: NSRect, in parent: NSView) -> NSView {
        let btn = NSView(frame: frame)
        btn.wantsLayer = true
        btn.layer?.cornerRadius = 6

        let grad = CAGradientLayer()
        grad.frame = CGRect(origin: .zero, size: frame.size)
        grad.colors = [DS.cardGreenTop.cgColor, DS.cardGreenBot.cgColor]
        grad.startPoint = CGPoint(x: 0.5, y: 0)
        grad.endPoint = CGPoint(x: 0.5, y: 1)
        grad.cornerRadius = 6
        btn.layer?.addSublayer(grad)

        let label = DS.label(text, size: 11, bold: true)
        label.translatesAutoresizingMaskIntoConstraints = true
        label.alignment = .center
        label.frame = NSRect(x: 0, y: 2, width: frame.width, height: frame.height - 4)
        btn.addSubview(label)

        return btn
    }
}

// MARK: - Flipped View (for scroll document)

private class FlippedView: NSView {
    override var isFlipped: Bool { true }
}
