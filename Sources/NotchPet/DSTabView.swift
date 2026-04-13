import AppKit
import QuartzCore

// MARK: - Tab Action

enum TabAction {
    case showDetail(pokemonId: String)
    case switchToTab(Int)
    case addToParty(id: String)
    case removeFromParty(id: String)
    case reorderParty(newOrder: [String])
    case cycleTier(bundleID: String)
    case toggleBerries
    case startBattle
    case battleMove(index: Int)
    case showCollection
}

// MARK: - DS Tab Protocol

protocol DSTab: AnyObject {
    var view: NSView { get }
    func update(state: PetState)
    var onAction: ((TabAction) -> Void)? { get set }
}

// MARK: - Hit Region

struct HitRegion {
    let id: String
    let rect: NSRect           // in view coordinates
    let action: TabAction      // what happens on click
    var enabled: Bool = true
}

// MARK: - DS Tab View (Base Class)

class DSTabView: NSView, DSTab {
    var onAction: ((TabAction) -> Void)?

    var view: NSView { return self }

    // Background image
    private let bgImageView = NSImageView()

    // Hit regions
    private(set) var hitRegions: [HitRegion] = []
    private var regionTrackingAreas: [NSTrackingArea] = []
    private var highlightLayer: CAShapeLayer?
    private var hoveredRegion: HitRegion?

    // DS colors
    static let hoverGold = NSColor(red: 0xF8/255, green: 0xA8/255, blue: 0x00/255, alpha: 1)
    static let selectedRed = NSColor(red: 0xF8/255, green: 0x38/255, blue: 0x38/255, alpha: 1)

    // MARK: - Init

    init(backgroundImage: String? = nil, backgroundColor: NSColor = .clear) {
        super.init(frame: .zero)
        wantsLayer = true

        if let bgName = backgroundImage {
            // Set up background image
            bgImageView.imageScaling = .scaleAxesIndependently
            bgImageView.translatesAutoresizingMaskIntoConstraints = false
            if let url = Bundle.module.url(forResource: bgName, withExtension: "png"),
               let img = NSImage(contentsOf: url) {
                bgImageView.image = img
            }
            addSubview(bgImageView)
            NSLayoutConstraint.activate([
                bgImageView.topAnchor.constraint(equalTo: topAnchor),
                bgImageView.leadingAnchor.constraint(equalTo: leadingAnchor),
                bgImageView.trailingAnchor.constraint(equalTo: trailingAnchor),
                bgImageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
        } else {
            // Solid background color — no image
            layer?.backgroundColor = backgroundColor.cgColor
        }

        // Highlight layer for hover
        let hl = CAShapeLayer()
        hl.fillColor = nil
        hl.strokeColor = DSTabView.hoverGold.cgColor
        hl.lineWidth = 2.5
        hl.isHidden = true
        layer?.addSublayer(hl)
        highlightLayer = hl
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - DSTab Protocol

    func update(state: PetState) {
        // Subclasses override this
    }

    /// Override in subclasses to skip hover tracking (e.g. when using a scroll view)
    var disableHoverTracking: Bool { false }

    // MARK: - Hit Region Management

    func clearHitRegions() {
        hitRegions.removeAll()
        for area in regionTrackingAreas {
            removeTrackingArea(area)
        }
        regionTrackingAreas.removeAll()
    }

    func addHitRegion(_ region: HitRegion) {
        hitRegions.append(region)

        guard !disableHoverTracking else { return }

        let area = NSTrackingArea(
            rect: region.rect,
            options: [.mouseEnteredAndExited, .activeInActiveApp],
            owner: self,
            userInfo: ["id": region.id]
        )
        addTrackingArea(area)
        regionTrackingAreas.append(area)
    }

    // MARK: - Mouse Events

    override func mouseEntered(with event: NSEvent) {
        guard let userInfo = event.trackingArea?.userInfo,
              let id = userInfo["id"] as? String,
              let region = hitRegions.first(where: { $0.id == id && $0.enabled })
        else { return }

        hoveredRegion = region
        showHighlight(for: region.rect)
        NSCursor.pointingHand.push()
    }

    override func mouseExited(with event: NSEvent) {
        hoveredRegion = nil
        hideHighlight()
        NSCursor.pop()
    }

    override func mouseDown(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        for region in hitRegions where region.enabled {
            if region.rect.contains(loc) {
                // Visual feedback: quick flash
                flashRegion(region.rect)
                onAction?(region.action)
                return
            }
        }
    }

    // MARK: - Highlight Rendering

    private func showHighlight(for rect: NSRect) {
        guard let hl = highlightLayer else { return }
        let path = CGPath(roundedRect: rect.insetBy(dx: -1, dy: -1), cornerWidth: 6, cornerHeight: 6, transform: nil)
        hl.path = path
        hl.isHidden = false

        // Subtle pulse animation
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 0.7
        pulse.toValue = 1.0
        pulse.duration = 0.6
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        hl.add(pulse, forKey: "pulse")
    }

    private func hideHighlight() {
        highlightLayer?.isHidden = true
        highlightLayer?.removeAllAnimations()
    }

    private func flashRegion(_ rect: NSRect) {
        let flash = CAShapeLayer()
        flash.path = CGPath(roundedRect: rect, cornerWidth: 6, cornerHeight: 6, transform: nil)
        flash.fillColor = NSColor.white.withAlphaComponent(0.3).cgColor
        layer?.addSublayer(flash)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            flash.removeFromSuperlayer()
        }
    }

    // MARK: - DS Text Helper

    static func dsLabel(_ text: String, size: CGFloat, bold: Bool = true, color: NSColor = .white) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size)
        label.textColor = color
        label.drawsBackground = false
        label.isBordered = false
        label.isEditable = false
        label.shadow = dsShadow()
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    static func dsShadow() -> NSShadow {
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.6)
        shadow.shadowOffset = NSSize(width: 1, height: -1)
        shadow.shadowBlurRadius = 0
        return shadow
    }

    static func dsSprite(for id: String, shiny: Bool = false, size: CGFloat = 44) -> NSImageView {
        let iv = NSImageView()
        iv.image = PetCollection.spriteImage(for: id, shiny: shiny)
        iv.imageScaling = .scaleProportionallyUpOrDown
        iv.wantsLayer = true
        iv.layer?.magnificationFilter = .nearest  // crispy pixel art
        iv.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iv.widthAnchor.constraint(equalToConstant: size),
            iv.heightAnchor.constraint(equalToConstant: size),
        ])
        return iv
    }
}
