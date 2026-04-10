import AppKit

final class OnboardingWindow: NSWindow {

    var onAccessibilityGranted: (() -> Void)?
    private var pollTimer: Timer?

    init() {
        let width: CGFloat = 420
        let height: CGFloat = 320

        // Center on screen
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let x = screen.frame.midX - width / 2
        let y = screen.frame.midY - height / 2

        super.init(
            contentRect: NSRect(x: x, y: y, width: width, height: height),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        title = "Welcome to NotchPet!"
        isReleasedWhenClosed = false
        level = .floating

        buildUI()
    }

    // MARK: - UI

    private func buildUI() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: frame.width, height: frame.height))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(red: 0x0d/255, green: 0x0d/255, blue: 0x0d/255, alpha: 1).cgColor
        contentView = container

        var y: CGFloat = frame.height - 40

        // Title
        let title = makeLabel("NotchPet needs your permission", size: 18, bold: true)
        title.frame = NSRect(x: 30, y: y - 24, width: 360, height: 24)
        container.addSubview(title)
        y -= 56

        // Explanation
        let explanation = makeLabel(
            "NotchPet watches your typing to give your Pokemon XP. " +
            "This requires Accessibility permission in macOS.\n\n" +
            "Your keystrokes are never recorded or sent anywhere — " +
            "NotchPet only counts them locally.",
            size: 13, bold: false
        )
        explanation.maximumNumberOfLines = 0
        explanation.preferredMaxLayoutWidth = 360
        explanation.frame = NSRect(x: 30, y: y - 80, width: 360, height: 80)
        container.addSubview(explanation)
        y -= 100

        // Steps
        let steps = [
            "1. Click \"Open Settings\" below",
            "2. Find NotchPet in the list",
            "3. Toggle it ON",
        ]
        for step in steps {
            let label = makeLabel(step, size: 13, bold: false)
            label.textColor = NSColor(red: 0.7, green: 0.9, blue: 0.7, alpha: 1)
            label.frame = NSRect(x: 50, y: y - 18, width: 320, height: 18)
            container.addSubview(label)
            y -= 24
        }

        let hint = makeLabel(
            "If NotchPet isn't in the list, click + and select\n/Applications/NotchPet.app",
            size: 11, bold: false
        )
        hint.textColor = .gray
        hint.maximumNumberOfLines = 2
        hint.frame = NSRect(x: 50, y: y - 36, width: 320, height: 36)
        container.addSubview(hint)
        y -= 48

        // Open Settings button
        let button = NSButton(title: "Open Settings", target: self, action: #selector(openAccessibilitySettings))
        button.bezelStyle = .rounded
        button.controlSize = .large
        button.font = NSFont.boldSystemFont(ofSize: 14)
        button.frame = NSRect(x: (frame.width - 180) / 2, y: 20, width: 180, height: 40)
        container.addSubview(button)

        // Status label
        let status = makeLabel("Waiting for permission...", size: 11, bold: false)
        status.textColor = .gray
        status.alignment = .center
        status.tag = 999
        status.frame = NSRect(x: 30, y: 64, width: 360, height: 16)
        container.addSubview(status)
    }

    // MARK: - Actions

    @objc private func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    // MARK: - Polling

    func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if AXIsProcessTrusted() {
                // Double-check by attempting a tap
                if self.verifyTapWorks() {
                    self.pollTimer?.invalidate()
                    self.pollTimer = nil
                    self.handleGranted()
                }
            }
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func verifyTapWorks() -> Bool {
        // Try to create an event tap — if it succeeds, we truly have permission
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, _, event, _ in Unmanaged.passUnretained(event) },
            userInfo: nil
        ) else {
            return false
        }
        // Clean up the test tap immediately
        CGEvent.tapEnable(tap: tap, enable: false)
        return true
    }

    private func handleGranted() {
        // Update status
        if let status = contentView?.viewWithTag(999) as? NSTextField {
            status.stringValue = "Permission granted! Starting NotchPet..."
            status.textColor = NSColor(red: 0.3, green: 0.9, blue: 0.3, alpha: 1)
        }

        // Brief delay so user sees the success message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.close()
            self?.onAccessibilityGranted?()
        }
    }

    // MARK: - Helpers

    private func makeLabel(_ text: String, size: CGFloat, bold: Bool) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size)
        label.textColor = .white
        label.isBordered = false
        label.drawsBackground = false
        label.isEditable = false
        label.lineBreakMode = .byWordWrapping
        return label
    }
}
