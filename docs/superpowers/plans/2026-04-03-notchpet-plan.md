# NotchPet Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a macOS menu bar pet app that renders an animated pixel-art blob to the left of the MacBook notch on an all-black background.

**Architecture:** Swift Package Manager executable that creates a borderless NSWindow positioned at the notch. The pet sprite is rendered via NSImageView with Core Animation (CABasicAnimation/CAKeyframeAnimation) for idle animations. No Xcode required — builds with `swift build` and a shell script packages the .app bundle.

**Tech Stack:** Swift 6.3, AppKit (NSWindow, NSImageView, NSMenu), Core Animation, SMAppService (Login Items), Swift Package Manager

---

## File Structure

```
NotchPet/
  Package.swift                         -- SPM manifest, macOS 14+, executable target
  Sources/NotchPet/
    main.swift                          -- NSApplication bootstrap, AppDelegate setup
    AppDelegate.swift                   -- Creates PetWindow, starts animations, menu
    PetWindow.swift                     -- Borderless black NSWindow, notch positioning
    PetView.swift                       -- NSImageView subclass, Core Animation idle anims
    PetInteraction.swift                -- Click squish, drag handling, right-click menu
    WalkController.swift                -- Timer-driven periodic walking
    Preferences.swift                   -- UserDefaults wrapper (position, speed, auto-launch)
  Resources/
    blob.png                            -- Pet sprite with transparency
    Info.plist                          -- LSUIElement = true, bundle ID
  Scripts/
    bundle.sh                           -- Builds binary, assembles .app bundle
    install.sh                          -- Copies .app to /Applications, enables Login Item
  Tests/NotchPetTests/
    PreferencesTests.swift              -- UserDefaults read/write
    WalkControllerTests.swift           -- Walk timing, cooldown logic
```

---

### Task 1: Project Scaffold & Window

**Files:**
- Create: `Package.swift`
- Create: `Sources/NotchPet/main.swift`
- Create: `Sources/NotchPet/AppDelegate.swift`
- Create: `Sources/NotchPet/PetWindow.swift`
- Create: `Resources/Info.plist`

- [ ] **Step 1: Create Package.swift**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NotchPet",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "NotchPet",
            resources: [
                .copy("../../Resources/blob.png"),
            ]
        ),
        .testTarget(
            name: "NotchPetTests",
            dependencies: ["NotchPet"]
        ),
    ]
)
```

- [ ] **Step 2: Create Resources/Info.plist**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.notchpet.app</string>
    <key>CFBundleName</key>
    <string>NotchPet</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
```

- [ ] **Step 3: Create main.swift — NSApplication bootstrap**

```swift
import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)  // No dock icon
app.run()
```

- [ ] **Step 4: Create AppDelegate.swift — window creation**

```swift
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var petWindow: PetWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        petWindow = PetWindow()
        petWindow.show()
    }
}
```

- [ ] **Step 5: Create PetWindow.swift — borderless black window at notch**

```swift
import AppKit

class PetWindow: NSWindow {
    static let petSize: CGFloat = 36

    init() {
        let frame = PetWindow.calculateFrame()
        super.init(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        self.level = .statusBar
        self.backgroundColor = .black
        self.isOpaque = true
        self.hasShadow = false
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]
        self.ignoresMouseEvents = false
    }

    func show() {
        self.orderFrontRegardless()
    }

    static func calculateFrame() -> NSRect {
        guard let screen = NSScreen.main else {
            return NSRect(x: 0, y: 0, width: petSize, height: petSize)
        }

        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame
        let menuBarHeight = screenFrame.height - visibleFrame.height - visibleFrame.origin.y

        // The notch is centered horizontally on the screen.
        // auxiliaryTopLeftArea gives us the usable area to the left of the notch.
        // We position our window at the right edge of that area (flush with the notch).
        let auxiliaryTopLeft = screen.auxiliaryTopLeftArea ?? NSRect.zero
        let windowWidth = petSize + 4  // small padding
        let windowHeight = menuBarHeight

        let x: CGFloat
        if auxiliaryTopLeft != .zero {
            // Right edge of the auxiliary area = left edge of notch
            x = auxiliaryTopLeft.origin.x + auxiliaryTopLeft.width - windowWidth
        } else {
            // Fallback: assume notch is centered, ~180pt wide
            let notchWidth: CGFloat = 180
            x = (screenFrame.width - notchWidth) / 2 - windowWidth
        }

        let y = screenFrame.height - windowHeight

        return NSRect(x: x, y: y, width: windowWidth, height: windowHeight)
    }
}
```

- [ ] **Step 6: Build and verify the black window appears**

Run:
```bash
cd ~/Developer/NotchPet && swift build 2>&1
```
Then run the app:
```bash
.build/debug/NotchPet &
```
Expected: A small black rectangle appears at the top of the screen, to the left of the notch. Kill it with `kill %1`.

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "feat: project scaffold with borderless black window at notch"
```

---

### Task 2: Pet Sprite with Idle Animations

**Files:**
- Create: `Sources/NotchPet/PetView.swift`
- Modify: `Sources/NotchPet/AppDelegate.swift`
- Modify: `Sources/NotchPet/PetWindow.swift`
- Copy: `Resources/blob.png` (from user's Downloads)

- [ ] **Step 1: Prepare the sprite asset**

Copy the user's image and remove the white background programmatically (we'll do this in code at load time — simpler than requiring image editing tools):

```bash
cp "/Users/haydenerwin/Downloads/Generated Image April 03, 2026 - 5_14PM - Edited.png" ~/Developer/NotchPet/Resources/blob.png
```

- [ ] **Step 2: Update Package.swift resource path**

The resource copy path needs to reference from the Sources/NotchPet directory. Update Package.swift so the resource is accessible via `Bundle.module`:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NotchPet",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "NotchPet",
            resources: [
                .copy("../../Resources/blob.png"),
            ]
        ),
        .testTarget(
            name: "NotchPetTests",
            dependencies: ["NotchPet"]
        ),
    ]
)
```

Note: SPM resource paths are relative to the target's source directory (`Sources/NotchPet/`). If `../../Resources/blob.png` doesn't work, we'll move blob.png into `Sources/NotchPet/Resources/blob.png` and use `.copy("Resources/blob.png")` instead.

- [ ] **Step 3: Create PetView.swift — image view with Core Animation**

```swift
import AppKit
import QuartzCore

class PetView: NSView {
    private let imageView = NSImageView()
    private var blinkTimer: Timer?

    enum AnimationSpeed: String, CaseIterable {
        case slow, normal, fast

        var breathingDuration: CFTimeInterval {
            switch self {
            case .slow: return 4.5
            case .normal: return 3.0
            case .fast: return 1.5
            }
        }

        var wiggleDuration: CFTimeInterval {
            switch self {
            case .slow: return 7.0
            case .normal: return 5.0
            case .fast: return 2.5
            }
        }

        var blinkInterval: ClosedRange<Double> {
            switch self {
            case .slow: return 6.0...10.0
            case .normal: return 4.0...6.0
            case .fast: return 2.0...3.5
            }
        }
    }

    var animationSpeed: AnimationSpeed = .normal {
        didSet { restartAnimations() }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor

        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        addSubview(imageView)

        loadSprite()
    }

    override func layout() {
        super.layout()
        // Center the image within the view with padding
        let padding: CGFloat = 2
        let size = min(bounds.width, bounds.height) - padding * 2
        imageView.frame = NSRect(
            x: (bounds.width - size) / 2,
            y: (bounds.height - size) / 2,
            width: size,
            height: size
        )
    }

    private func loadSprite() {
        guard let url = Bundle.module.url(forResource: "blob", withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            // Fallback: draw a blue circle if image not found
            let fallback = NSImage(size: NSSize(width: 32, height: 32), flipped: false) { rect in
                NSColor.cyan.setFill()
                NSBezierPath(ovalIn: rect).fill()
                return true
            }
            imageView.image = fallback
            return
        }

        // Remove white background by making near-white pixels transparent
        if let tiffData = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let cgImage = bitmap.cgImage {
            let processed = PetView.removeWhiteBackground(from: cgImage)
            imageView.image = NSImage(cgImage: processed, size: image.size)
        } else {
            imageView.image = image
        }
    }

    static func removeWhiteBackground(from image: CGImage) -> CGImage {
        let width = image.width
        let height = image.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        var pixelData = [UInt8](repeating: 0, count: height * bytesPerRow)

        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Make near-white pixels transparent (threshold: RGB all > 240)
        let threshold: UInt8 = 240
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * bytesPerRow) + (x * bytesPerPixel)
                let r = pixelData[offset]
                let g = pixelData[offset + 1]
                let b = pixelData[offset + 2]
                if r > threshold && g > threshold && b > threshold {
                    pixelData[offset + 3] = 0  // Set alpha to 0
                    pixelData[offset] = 0
                    pixelData[offset + 1] = 0
                    pixelData[offset + 2] = 0
                }
            }
        }

        guard let newContext = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let newImage = newContext.makeImage() else { return image }

        return newImage
    }

    // MARK: - Animations

    func startAnimations() {
        startBreathing()
        startWiggle()
        scheduleBlink()
    }

    func stopAnimations() {
        imageView.layer?.removeAllAnimations()
        blinkTimer?.invalidate()
        blinkTimer = nil
    }

    func restartAnimations() {
        stopAnimations()
        startAnimations()
    }

    private func startBreathing() {
        let anim = CABasicAnimation(keyPath: "transform.scale")
        anim.fromValue = 1.0
        anim.toValue = 1.05
        anim.duration = animationSpeed.breathingDuration / 2
        anim.autoreverses = true
        anim.repeatCount = .infinity
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        imageView.layer?.add(anim, forKey: "breathing")
    }

    private func startWiggle() {
        let anim = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        let angle = CGFloat.pi / 60  // ~3 degrees
        anim.values = [0, angle, 0, -angle, 0]
        anim.keyTimes = [0, 0.25, 0.5, 0.75, 1.0]
        anim.duration = animationSpeed.wiggleDuration
        anim.repeatCount = .infinity
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        imageView.layer?.add(anim, forKey: "wiggle")
    }

    private func scheduleBlink() {
        let range = animationSpeed.blinkInterval
        let interval = Double.random(in: range)
        blinkTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.doBlink()
            self?.scheduleBlink()
        }
    }

    private func doBlink() {
        let anim = CAKeyframeAnimation(keyPath: "transform.scale.y")
        anim.values = [1.0, 0.1, 1.0]
        anim.keyTimes = [0, 0.4, 1.0]
        anim.duration = 0.15
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        imageView.layer?.add(anim, forKey: "blink")
    }

    // MARK: - Click squish

    func squish() {
        let anim = CAKeyframeAnimation(keyPath: "transform.scale.y")
        anim.values = [1.0, 0.7, 1.1, 1.0]
        anim.keyTimes = [0, 0.3, 0.7, 1.0]
        anim.duration = 0.3
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        imageView.layer?.add(anim, forKey: "squish")
    }
}
```

- [ ] **Step 4: Wire PetView into PetWindow and AppDelegate**

Update `PetWindow.swift` — add the pet view:

```swift
import AppKit

class PetWindow: NSWindow {
    static let petSize: CGFloat = 36
    let petView: PetView

    init() {
        let frame = PetWindow.calculateFrame()
        petView = PetView(frame: NSRect(x: 0, y: 0, width: frame.width, height: frame.height))

        super.init(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        self.level = .statusBar
        self.backgroundColor = .black
        self.isOpaque = true
        self.hasShadow = false
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]
        self.ignoresMouseEvents = false
        self.contentView = petView
    }

    func show() {
        self.orderFrontRegardless()
        petView.startAnimations()
    }

    static func calculateFrame() -> NSRect {
        guard let screen = NSScreen.main else {
            return NSRect(x: 0, y: 0, width: petSize + 4, height: 37)
        }

        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame
        let menuBarHeight = screenFrame.height - visibleFrame.height - visibleFrame.origin.y

        let auxiliaryTopLeft = screen.auxiliaryTopLeftArea ?? NSRect.zero
        let windowWidth = petSize + 4
        let windowHeight = menuBarHeight

        let x: CGFloat
        if auxiliaryTopLeft != .zero {
            x = auxiliaryTopLeft.origin.x + auxiliaryTopLeft.width - windowWidth
        } else {
            let notchWidth: CGFloat = 180
            x = (screenFrame.width - notchWidth) / 2 - windowWidth
        }

        let y = screenFrame.height - windowHeight

        return NSRect(x: x, y: y, width: windowWidth, height: windowHeight)
    }
}
```

- [ ] **Step 5: Build and verify sprite renders with animations**

```bash
cd ~/Developer/NotchPet && swift build 2>&1
.build/debug/NotchPet &
```
Expected: The blue blob appears to the left of the notch on a black background, gently breathing, wiggling, and blinking. Kill with `kill %1`.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: pet sprite rendering with idle animations (breathing, wiggle, blink)"
```

---

### Task 3: Click, Drag, and Right-Click Menu

**Files:**
- Create: `Sources/NotchPet/PetInteraction.swift`
- Create: `Sources/NotchPet/Preferences.swift`
- Modify: `Sources/NotchPet/AppDelegate.swift`

- [ ] **Step 1: Create Preferences.swift**

```swift
import Foundation
import ServiceManagement

class Preferences {
    static let shared = Preferences()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let windowX = "windowX"
        static let hasSetPosition = "hasSetPosition"
        static let animationSpeed = "animationSpeed"
        static let hasLaunchedBefore = "hasLaunchedBefore"
    }

    var savedWindowX: CGFloat? {
        get {
            guard defaults.bool(forKey: Keys.hasSetPosition) else { return nil }
            return CGFloat(defaults.double(forKey: Keys.windowX))
        }
        set {
            if let x = newValue {
                defaults.set(Double(x), forKey: Keys.windowX)
                defaults.set(true, forKey: Keys.hasSetPosition)
            } else {
                defaults.removeObject(forKey: Keys.windowX)
                defaults.set(false, forKey: Keys.hasSetPosition)
            }
        }
    }

    var animationSpeed: PetView.AnimationSpeed {
        get {
            let raw = defaults.string(forKey: Keys.animationSpeed) ?? "normal"
            return PetView.AnimationSpeed(rawValue: raw) ?? .normal
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.animationSpeed)
        }
    }

    var isAutoLaunchEnabled: Bool {
        get {
            return SMAppService.mainApp.status == .enabled
        }
        set {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to \(newValue ? "enable" : "disable") auto-launch: \(error)")
            }
        }
    }

    var hasLaunchedBefore: Bool {
        get { defaults.bool(forKey: Keys.hasLaunchedBefore) }
        set { defaults.set(newValue, forKey: Keys.hasLaunchedBefore) }
    }
}
```

- [ ] **Step 2: Create PetInteraction.swift — click, drag, right-click**

```swift
import AppKit

class PetInteraction {
    private weak var window: PetWindow?
    private var isDragging = false
    private var dragOffset: CGFloat = 0
    var lastDragTime: Date = .distantPast

    init(window: PetWindow) {
        self.window = window
        setupEventMonitors()
    }

    private func setupEventMonitors() {
        guard let window = window else { return }
        let petView = window.petView

        // Override mouseDown/mouseUp/mouseDragged/rightMouseDown on the petView
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleClick(_:)))
        clickGesture.numberOfClicksRequired = 1
        petView.addGestureRecognizer(clickGesture)
    }

    @objc private func handleClick(_ gesture: NSClickGestureRecognizer) {
        guard !isDragging else { return }
        window?.petView.squish()
    }

    func handleMouseDown(event: NSEvent) {
        guard let window = window else { return }
        let windowFrame = window.frame
        let mouseLocation = NSEvent.mouseLocation
        dragOffset = mouseLocation.x - windowFrame.origin.x
        isDragging = false
    }

    func handleMouseDragged(event: NSEvent) {
        guard let window = window else { return }
        isDragging = true
        let mouseLocation = NSEvent.mouseLocation
        var newOrigin = window.frame.origin
        newOrigin.x = mouseLocation.x - dragOffset
        // Lock Y position to menu bar
        window.setFrameOrigin(newOrigin)
        lastDragTime = Date()
        Preferences.shared.savedWindowX = newOrigin.x
    }

    func handleMouseUp(event: NSEvent) {
        if isDragging {
            lastDragTime = Date()
        }
        isDragging = false
    }

    func showContextMenu(event: NSEvent) {
        guard let window = window else { return }

        let menu = NSMenu()

        // Animation Speed submenu
        let speedItem = NSMenuItem(title: "Animation Speed", action: nil, keyEquivalent: "")
        let speedMenu = NSMenu()
        for speed in PetView.AnimationSpeed.allCases {
            let item = NSMenuItem(
                title: speed.rawValue.capitalized,
                action: #selector(setSpeed(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = speed
            if speed == Preferences.shared.animationSpeed {
                item.state = .on
            }
            speedMenu.addItem(item)
        }
        speedItem.submenu = speedMenu
        menu.addItem(speedItem)

        // Auto-Launch toggle
        let autoLaunchItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleAutoLaunch(_:)),
            keyEquivalent: ""
        )
        autoLaunchItem.target = self
        autoLaunchItem.state = Preferences.shared.isAutoLaunchEnabled ? .on : .off
        menu.addItem(autoLaunchItem)

        menu.addItem(NSMenuItem.separator())

        // Reset Position
        let resetItem = NSMenuItem(
            title: "Reset Position",
            action: #selector(resetPosition(_:)),
            keyEquivalent: ""
        )
        resetItem.target = self
        menu.addItem(resetItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(
            title: "Quit NotchPet",
            action: #selector(quit(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        NSMenu.popUpContextMenu(menu, with: event, for: window.petView)
    }

    @objc private func setSpeed(_ sender: NSMenuItem) {
        guard let speed = sender.representedObject as? PetView.AnimationSpeed else { return }
        Preferences.shared.animationSpeed = speed
        window?.petView.animationSpeed = speed
    }

    @objc private func toggleAutoLaunch(_ sender: NSMenuItem) {
        let current = Preferences.shared.isAutoLaunchEnabled
        Preferences.shared.isAutoLaunchEnabled = !current
    }

    @objc private func resetPosition(_ sender: NSMenuItem) {
        guard let window = window else { return }
        Preferences.shared.savedWindowX = nil
        let frame = PetWindow.calculateFrame()
        window.setFrameOrigin(frame.origin)
    }

    @objc private func quit(_ sender: NSMenuItem) {
        NSApp.terminate(nil)
    }
}
```

- [ ] **Step 3: Update PetView to handle mouse events and forward to PetInteraction**

Add to the bottom of `PetView.swift`:

```swift
// MARK: - Mouse Events (forwarded to PetInteraction)

extension PetView {
    var interaction: PetInteraction? {
        get { objc_getAssociatedObject(self, &AssociatedKeys.interaction) as? PetInteraction }
        set { objc_setAssociatedObject(self, &AssociatedKeys.interaction, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    private enum AssociatedKeys {
        static var interaction = "petInteraction"
    }

    override func mouseDown(with event: NSEvent) {
        interaction?.handleMouseDown(event: event)
    }

    override func mouseDragged(with event: NSEvent) {
        interaction?.handleMouseDragged(event: event)
    }

    override func mouseUp(with event: NSEvent) {
        interaction?.handleMouseUp(event: event)
        // If it wasn't a drag, treat as click
        if event.clickCount == 1 {
            squish()
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        interaction?.showContextMenu(event: event)
    }
}
```

- [ ] **Step 4: Update AppDelegate to wire interaction and restore position**

```swift
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var petWindow: PetWindow!
    var interaction: PetInteraction!

    func applicationDidFinishLaunching(_ notification: Notification) {
        petWindow = PetWindow()

        // Restore saved position
        if let savedX = Preferences.shared.savedWindowX {
            var origin = petWindow.frame.origin
            origin.x = savedX
            petWindow.setFrameOrigin(origin)
        }

        // Apply saved animation speed
        petWindow.petView.animationSpeed = Preferences.shared.animationSpeed

        interaction = PetInteraction(window: petWindow)
        petWindow.petView.interaction = interaction

        // Enable auto-launch on first run
        if !Preferences.shared.hasLaunchedBefore {
            Preferences.shared.isAutoLaunchEnabled = true
            Preferences.shared.hasLaunchedBefore = true
        }

        petWindow.show()
    }
}
```

- [ ] **Step 5: Build and verify interactions**

```bash
cd ~/Developer/NotchPet && swift build 2>&1
.build/debug/NotchPet &
```
Test:
- Left-click the pet → squish animation
- Right-click → context menu with Speed, Launch at Login, Reset Position, Quit
- Click-drag → moves horizontally along menu bar
- Kill with Quit menu item or `kill %1`

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: click squish, drag repositioning, right-click context menu"
```

---

### Task 4: Walking Behavior

**Files:**
- Create: `Sources/NotchPet/WalkController.swift`
- Modify: `Sources/NotchPet/AppDelegate.swift`

- [ ] **Step 1: Create WalkController.swift**

```swift
import AppKit

class WalkController {
    private weak var window: PetWindow?
    private weak var interaction: PetInteraction?
    private var walkTimer: Timer?
    private var isWalking = false

    // Configurable for testing
    var walkIntervalRange: ClosedRange<Double> = 120...300  // 2-5 minutes
    var walkDistance: ClosedRange<CGFloat> = 30...50
    var dragCooldown: TimeInterval = 60  // 1 minute

    init(window: PetWindow, interaction: PetInteraction) {
        self.window = window
        self.interaction = interaction
        scheduleNextWalk()
    }

    func stop() {
        walkTimer?.invalidate()
        walkTimer = nil
    }

    private func scheduleNextWalk() {
        let interval = Double.random(in: walkIntervalRange)
        walkTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.walk()
        }
    }

    private func walk() {
        guard let window = window, !isWalking else {
            scheduleNextWalk()
            return
        }

        // Don't walk if user dragged recently
        if let interaction = interaction,
           Date().timeIntervalSince(interaction.lastDragTime) < dragCooldown {
            scheduleNextWalk()
            return
        }

        isWalking = true
        let distance = CGFloat.random(in: walkDistance) * (Bool.random() ? 1 : -1)
        let startX = window.frame.origin.x
        let targetX = startX + distance

        // Clamp to screen bounds
        guard let screen = NSScreen.main else {
            isWalking = false
            scheduleNextWalk()
            return
        }
        let clampedX = max(0, min(targetX, screen.frame.width - window.frame.width))

        // Animate: walk to target over ~2 seconds with a waddle
        let steps = 20
        let stepDuration = 2.0 / Double(steps)
        let stepDistance = (clampedX - startX) / CGFloat(steps)

        animateWalkSteps(
            currentStep: 0,
            totalSteps: steps,
            stepDuration: stepDuration,
            stepDistance: stepDistance,
            startX: startX
        )
    }

    private func animateWalkSteps(
        currentStep: Int,
        totalSteps: Int,
        stepDuration: Double,
        stepDistance: CGFloat,
        startX: CGFloat
    ) {
        guard currentStep < totalSteps, let window = window else {
            isWalking = false
            // Save new position
            if let window = window {
                Preferences.shared.savedWindowX = window.frame.origin.x
            }
            scheduleNextWalk()
            return
        }

        // Waddle: alternate tilt
        let tiltAngle: CGFloat = (currentStep % 2 == 0) ? 0.05 : -0.05
        let tiltAnim = CABasicAnimation(keyPath: "transform.rotation.z")
        tiltAnim.toValue = tiltAngle
        tiltAnim.duration = stepDuration
        tiltAnim.autoreverses = false
        window.petView.layer?.add(tiltAnim, forKey: "waddle")

        Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: false) { [weak self] _ in
            var origin = window.frame.origin
            origin.x += stepDistance
            window.setFrameOrigin(origin)

            self?.animateWalkSteps(
                currentStep: currentStep + 1,
                totalSteps: totalSteps,
                stepDuration: stepDuration,
                stepDistance: stepDistance,
                startX: startX
            )
        }
    }
}
```

- [ ] **Step 2: Wire WalkController into AppDelegate**

```swift
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var petWindow: PetWindow!
    var interaction: PetInteraction!
    var walkController: WalkController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        petWindow = PetWindow()

        if let savedX = Preferences.shared.savedWindowX {
            var origin = petWindow.frame.origin
            origin.x = savedX
            petWindow.setFrameOrigin(origin)
        }

        petWindow.petView.animationSpeed = Preferences.shared.animationSpeed

        interaction = PetInteraction(window: petWindow)
        petWindow.petView.interaction = interaction

        walkController = WalkController(window: petWindow, interaction: interaction)

        if !Preferences.shared.hasLaunchedBefore {
            Preferences.shared.isAutoLaunchEnabled = true
            Preferences.shared.hasLaunchedBefore = true
        }

        petWindow.show()
    }
}
```

- [ ] **Step 3: Build and verify**

```bash
cd ~/Developer/NotchPet && swift build 2>&1
.build/debug/NotchPet &
```
Expected: Pet sits at notch with all animations. Walking will trigger after 2-5 minutes. To test walking sooner, temporarily change `walkIntervalRange` to `5...10` (seconds), rebuild, and observe.

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat: periodic walking with waddle animation and drag cooldown"
```

---

### Task 5: App Bundle & Install Script

**Files:**
- Create: `Scripts/bundle.sh`
- Create: `Scripts/install.sh`

- [ ] **Step 1: Create Scripts/bundle.sh**

```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="NotchPet"
APP_BUNDLE="$PROJECT_DIR/.build/${APP_NAME}.app"

echo "Building $APP_NAME..."
cd "$PROJECT_DIR"
swift build -c release 2>&1

echo "Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary
cp ".build/release/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Copy Info.plist
cp "Resources/Info.plist" "$APP_BUNDLE/Contents/"

# Copy sprite (SPM bundles resources automatically, but we also include it
# in the app bundle Resources for fallback)
cp "Resources/blob.png" "$APP_BUNDLE/Contents/Resources/"

echo "App bundle created at: $APP_BUNDLE"
echo ""
echo "To install, run: ./Scripts/install.sh"
echo "Or manually copy to /Applications:"
echo "  cp -r '$APP_BUNDLE' /Applications/"
```

- [ ] **Step 2: Create Scripts/install.sh**

```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="NotchPet"
APP_BUNDLE="$PROJECT_DIR/.build/${APP_NAME}.app"
INSTALL_DIR="/Applications"

if [ ! -d "$APP_BUNDLE" ]; then
    echo "App bundle not found. Building first..."
    bash "$SCRIPT_DIR/bundle.sh"
fi

echo "Installing $APP_NAME to $INSTALL_DIR..."

# Remove old version if exists
if [ -d "$INSTALL_DIR/$APP_NAME.app" ]; then
    echo "Removing previous installation..."
    rm -rf "$INSTALL_DIR/$APP_NAME.app"
fi

cp -r "$APP_BUNDLE" "$INSTALL_DIR/$APP_NAME.app"

echo "Installed to $INSTALL_DIR/$APP_NAME.app"
echo ""
echo "Launching $APP_NAME..."
open "$INSTALL_DIR/$APP_NAME.app"
```

- [ ] **Step 3: Make scripts executable and test bundle**

```bash
chmod +x ~/Developer/NotchPet/Scripts/bundle.sh ~/Developer/NotchPet/Scripts/install.sh
cd ~/Developer/NotchPet && bash Scripts/bundle.sh
```
Expected: Release build succeeds, `.build/NotchPet.app` bundle is created.

- [ ] **Step 4: Test install and launch**

```bash
cd ~/Developer/NotchPet && bash Scripts/install.sh
```
Expected: App is copied to /Applications and launches. Pet appears at the notch. No Dock icon visible. Right-click → "Launch at Login" works. Quit via right-click menu.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: app bundle and install scripts"
```

---

### Task 6: Polish & Final Verification

- [ ] **Step 1: Add .gitignore**

```
.build/
.swiftpm/
*.app
```

- [ ] **Step 2: Full clean build and test**

```bash
cd ~/Developer/NotchPet
rm -rf .build
swift build -c release 2>&1
bash Scripts/bundle.sh
bash Scripts/install.sh
```

Verify all features:
- Pet appears to the left of the notch on black background
- Breathing, wiggle, and blink animations running
- Left-click → squish
- Right-click → menu (Speed, Launch at Login, Reset Position, Quit)
- Drag → repositions horizontally, position persists after restart
- No Dock icon
- Launch at Login toggleable

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "chore: add gitignore, final polish"
```
