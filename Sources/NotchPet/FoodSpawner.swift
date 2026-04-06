import AppKit
import QuartzCore

final class FoodSpawner {
    var onFoodEaten: ((String) -> Void)?
    var onPartyPokemonFed: ((String, String) -> Void)?  // (pokemonId, berryName)
    var partyFramesProvider: (() -> [(id: String, frame: NSRect)])?
    /// Called during drag to highlight the Pokemon under the food
    var onDragOverParty: ((NSRect) -> Void)?
    /// Called when drag ends (clear highlights)
    var onDragEnd: (() -> Void)?
    /// Called after feeding a party Pokemon (trigger bounce animation)
    var onPartyPokemonBounce: ((String) -> Void)?

    private var foodWindow: NSWindow?
    private var spawnTimer: Timer?
    private var despawnTimer: Timer?
    private let petWindowFrame: () -> NSRect
    private var isDragging = false
    private var currentBerryName: String?

    private static let berryNames = [
        "oran-berry", "sitrus-berry", "razz-berry", "cheri-berry",
        "pecha-berry", "rawst-berry", "leppa-berry", "lum-berry"
    ]

    init(petWindowFrame: @escaping () -> NSRect) {
        self.petWindowFrame = petWindowFrame
    }

    func start() {
        let delay = Double.random(in: 30...90)
        spawnTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.spawnBerry()
        }
    }

    func stop() {
        spawnTimer?.invalidate()
        spawnTimer = nil
        despawnTimer?.invalidate()
        despawnTimer = nil
        removeFoodWindow()
    }

    // MARK: - Spawning

    private func spawnBerry() {
        guard foodWindow == nil else { return }

        let berryName = Self.berryNames.randomElement()!
        currentBerryName = berryName

        guard let image = loadBerryImage(named: berryName) else {
            scheduleNextSpawn()
            return
        }

        let size: CGFloat = 30
        let origin = berrySpawnPoint(foodSize: size)

        let window = NSWindow(
            contentRect: NSRect(x: origin.x, y: origin.y, width: size, height: size),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.level = .statusBar
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.isMovableByWindowBackground = false
        window.alphaValue = 0

        let foodView = FoodView(frame: NSRect(x: 0, y: 0, width: size, height: size))
        foodView.imageView.image = image
        foodView.imageView.imageScaling = .scaleProportionallyUpOrDown
        foodView.spawner = self
        window.contentView = foodView

        foodWindow = window
        window.orderFront(nil)

        // Fade in
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            window.animator().alphaValue = 1.0
        }

        // Despawn after 30 seconds
        despawnTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { [weak self] _ in
            self?.despawnBerry()
        }
    }

    private func despawnBerry() {
        guard !isDragging, let window = foodWindow else { return }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.5
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.removeFoodWindow()
            self?.scheduleNextSpawn()
        })
    }

    private func scheduleNextSpawn() {
        spawnTimer?.invalidate()
        let delay = Double.random(in: 60...180)
        spawnTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.spawnBerry()
        }
    }

    private func removeFoodWindow() {
        foodWindow?.orderOut(nil)
        foodWindow = nil
        currentBerryName = nil
    }

    // MARK: - Drop Handling

    fileprivate func handleFoodDrop() {
        guard let window = foodWindow else { return }
        isDragging = false

        let foodFrame = window.frame

        // Check pet window first
        let petFrame = petWindowFrame()
        if foodFrame.intersects(petFrame) {
            eatBerry()
            return
        }

        // Check party Pokemon
        if let partyFrames = partyFramesProvider?() {
            for (pokemonId, pFrame) in partyFrames {
                if foodFrame.intersects(pFrame) {
                    feedPartyPokemon(pokemonId: pokemonId)
                    return
                }
            }
        }
        // If not overlapping anything, berry stays where it was dropped
    }

    fileprivate func handleDragStarted() {
        isDragging = true
    }

    private func eatBerry() {
        guard let window = foodWindow, let name = currentBerryName else { return }
        despawnTimer?.invalidate()
        despawnTimer = nil

        // Scale-up + fade-out animation
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.allowsImplicitAnimation = true
            window.animator().alphaValue = 0
            if let view = window.contentView {
                let midX = view.bounds.midX
                let midY = view.bounds.midY
                view.layer?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                view.layer?.position = CGPoint(x: midX, y: midY)

                let scaleUp = CABasicAnimation(keyPath: "transform.scale")
                scaleUp.fromValue = 1.0
                scaleUp.toValue = 1.5
                scaleUp.duration = 0.3
                view.layer?.add(scaleUp, forKey: "eatScale")
            }
        }, completionHandler: { [weak self] in
            self?.removeFoodWindow()
            self?.onFoodEaten?(name)
            self?.scheduleNextSpawn()
        })
    }

    private func feedPartyPokemon(pokemonId: String) {
        guard let window = foodWindow, let name = currentBerryName else { return }
        despawnTimer?.invalidate()
        despawnTimer = nil

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.allowsImplicitAnimation = true
            window.animator().alphaValue = 0
            if let view = window.contentView {
                let midX = view.bounds.midX
                let midY = view.bounds.midY
                view.layer?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                view.layer?.position = CGPoint(x: midX, y: midY)

                let scaleUp = CABasicAnimation(keyPath: "transform.scale")
                scaleUp.fromValue = 1.0
                scaleUp.toValue = 1.5
                scaleUp.duration = 0.3
                view.layer?.add(scaleUp, forKey: "eatScale")
            }
        }, completionHandler: { [weak self] in
            self?.removeFoodWindow()
            self?.onPartyPokemonBounce?(pokemonId)
            self?.onPartyPokemonFed?(pokemonId, name)
            self?.scheduleNextSpawn()
        })
    }

    // MARK: - Helpers

    private func berrySpawnPoint(foodSize: CGFloat) -> NSPoint {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let visible = screen.visibleFrame  // excludes menu bar and dock
        let margin: CGFloat = 40
        let x = visible.origin.x + CGFloat.random(in: margin...(visible.width - foodSize - margin))
        let y = visible.origin.y + CGFloat.random(in: margin...(visible.height - foodSize - margin))
        return NSPoint(x: x, y: y)
    }

    private func loadBerryImage(named name: String) -> NSImage? {
        guard let berriesURL = Bundle.module.url(forResource: "berries", withExtension: nil) else {
            return nil
        }
        let fileURL = berriesURL.appendingPathComponent("\(name).png")
        return NSImage(contentsOf: fileURL)
    }
}

// MARK: - FoodView

private class FoodView: NSView {
    let imageView = NSImageView()
    weak var spawner: FoodSpawner?
    private var dragStartLocation: NSPoint = .zero
    private var windowStartOrigin: NSPoint = .zero

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        imageView.frame = bounds
        imageView.autoresizingMask = [.width, .height]
        imageView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(imageView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func mouseDown(with event: NSEvent) {
        dragStartLocation = NSEvent.mouseLocation
        windowStartOrigin = window?.frame.origin ?? .zero
        spawner?.handleDragStarted()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window = window else { return }
        let currentMouse = NSEvent.mouseLocation
        let dx = currentMouse.x - dragStartLocation.x
        let dy = currentMouse.y - dragStartLocation.y
        let newOrigin = NSPoint(
            x: windowStartOrigin.x + dx,
            y: windowStartOrigin.y + dy
        )
        window.setFrameOrigin(newOrigin)
        // Highlight party Pokemon under the food
        spawner?.onDragOverParty?(window.frame)
    }

    override func mouseUp(with event: NSEvent) {
        spawner?.onDragEnd?()
        spawner?.handleFoodDrop()
    }
}
