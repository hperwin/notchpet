import AppKit

enum DS {
    static let outerPad: CGFloat = 10
    static let cardGap: CGFloat = 8
    static let innerPad: CGFloat = 12

    static let cardBg = NSColor(red: 0x1a/255.0, green: 0x1a/255.0, blue: 0x1a/255.0, alpha: 1)
    static let cardRadius: CGFloat = 10
    static let cardBorderColor = NSColor(red: 0x28/255.0, green: 0x68/255.0, blue: 0x28/255.0, alpha: 1)
    static let cardBorderWidth: CGFloat = 1

    static let gold = NSColor(red: 0xF8/255.0, green: 0xA8/255.0, blue: 0x00/255.0, alpha: 1)
    static let textPrimary = NSColor.white
    static let textSecondary = NSColor(red: 0x88/255.0, green: 0x88/255.0, blue: 0x88/255.0, alpha: 1)
    static let greenFill = NSColor(red: 0x48/255.0, green: 0xD0/255.0, blue: 0x48/255.0, alpha: 1)
    static let barTrack = NSColor(red: 0x1a/255.0, green: 0x1a/255.0, blue: 0x1a/255.0, alpha: 1)

    static let cardGreenTop = NSColor(red: 0x48/255.0, green: 0xB0/255.0, blue: 0x48/255.0, alpha: 1)
    static let cardGreenBot = NSColor(red: 0x38/255.0, green: 0xA0/255.0, blue: 0x38/255.0, alpha: 1)
    static let cardGreenBorder = NSColor(red: 0x28/255.0, green: 0x68/255.0, blue: 0x28/255.0, alpha: 1)

    static let navBlueTop = NSColor(red: 0x30/255.0, green: 0x58/255.0, blue: 0x90/255.0, alpha: 1)
    static let navBlueBot = NSColor(red: 0x20/255.0, green: 0x40/255.0, blue: 0x70/255.0, alpha: 1)
    static let navActiveGreenTop = NSColor(red: 0x48/255.0, green: 0xB0/255.0, blue: 0x48/255.0, alpha: 1)
    static let navActiveGreenBot = NSColor(red: 0x38/255.0, green: 0xA0/255.0, blue: 0x38/255.0, alpha: 1)
    static let navInactiveTop = NSColor(red: 0x40/255.0, green: 0x68/255.0, blue: 0x98/255.0, alpha: 1)
    static let navInactiveBot = NSColor(red: 0x30/255.0, green: 0x50/255.0, blue: 0x80/255.0, alpha: 1)

    static let boxTealTop = NSColor(red: 0x2D/255.0, green: 0x8B/255.0, blue: 0x6E/255.0, alpha: 1)
    static let boxTealBot = NSColor(red: 0x1A/255.0, green: 0x6B/255.0, blue: 0x4A/255.0, alpha: 1)
    static let boxCellBg = NSColor(red: 0x1A/255.0, green: 0x4A/255.0, blue: 0x3A/255.0, alpha: 1)

    static let pillBg = NSColor(red: 0x1A/255.0, green: 0x3A/255.0, blue: 0x1A/255.0, alpha: 1)
    static let pillRadius: CGFloat = 6
    static let barHeight: CGFloat = 4
    static let barRadius: CGFloat = 2

    static func dsShadow() -> NSShadow {
        let s = NSShadow()
        s.shadowColor = NSColor.black.withAlphaComponent(0.6)
        s.shadowOffset = NSSize(width: 1, height: -1)
        s.shadowBlurRadius = 0
        return s
    }

    static func makeCard(frame: NSRect) -> NSView {
        let v = NSView(frame: frame)
        v.wantsLayer = true
        v.layer?.backgroundColor = cardBg.cgColor
        v.layer?.cornerRadius = cardRadius
        v.layer?.borderColor = cardBorderColor.cgColor
        v.layer?.borderWidth = cardBorderWidth
        return v
    }

    static func label(_ text: String, size: CGFloat, bold: Bool = false, color: NSColor = .white) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.font = bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size)
        l.textColor = color
        l.drawsBackground = false
        l.isBordered = false
        l.isEditable = false
        l.shadow = dsShadow()
        return l
    }

    static func makeBar(in parent: NSView, x: CGFloat, y: CGFloat, width: CGFloat, progress: Double) {
        let w = max(width, 20)
        let track = NSView(frame: NSRect(x: x, y: y, width: w, height: barHeight))
        track.wantsLayer = true
        track.layer?.backgroundColor = barTrack.cgColor
        track.layer?.cornerRadius = barRadius
        parent.addSubview(track)
        let fillW = w * CGFloat(min(max(progress, 0), 1))
        if fillW > 0 {
            let fill = NSView(frame: NSRect(x: 0, y: 0, width: fillW, height: barHeight))
            fill.wantsLayer = true
            fill.layer?.backgroundColor = greenFill.cgColor
            fill.layer?.cornerRadius = barRadius
            track.addSubview(fill)
        }
    }
}
