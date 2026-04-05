import AppKit
import QuartzCore

final class PetView: NSView {
    let imageView = NSImageView()
    weak var interaction: PetInteraction?

    // Frame animation
    private var frames: [NSImage] = []
    private var currentFrameIndex = 0
    private var frameTimer: Timer?
    private var idleTimer: Timer?
    private let frameRate: TimeInterval = 1.0 / 15.0  // 15fps
    private var isAnimating = false

    // Running state
    enum PetDirection {
        case left, right
    }
    private(set) var direction: PetDirection = .right
    private(set) var isRunning = false
    private var runTimer: Timer?
    /// The pet's x position within the window (local coordinate)
    private(set) var petLocalX: CGFloat = 0
    private var runTarget: CGFloat = 0

    // Running bounds (set by AppDelegate after init)
    var minRunX: CGFloat = 0
    var maxRunX: CGFloat = 100

    // Home position (where the pet idles, left of notch)
    var homeX: CGFloat = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        loadFrames()

        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.image = frames.first
        addSubview(imageView)

        // Position imageView — will be moved by updatePetPosition()
        let size = PetWindow.petSize
        imageView.frame = NSRect(x: 0, y: (bounds.height - size) / 2, width: size, height: size)

        startFrameAnimation()
    }

    override func layout() {
        super.layout()
        updatePetPosition()
    }

    // MARK: - Frame Loading

    private func loadFrames() {
        guard let framesURL = Bundle.module.url(forResource: "frames", withExtension: nil) else {
            NSLog("NotchPet: frames directory not found, falling back to blob.png")
            if let blobURL = Bundle.module.url(forResource: "blob", withExtension: "png"),
               let img = NSImage(contentsOf: blobURL) {
                frames = [img]
            }
            return
        }

        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: framesURL, includingPropertiesForKeys: nil)
            .filter({ $0.pathExtension == "png" })
            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
        else {
            NSLog("NotchPet: couldn't list frames")
            return
        }

        frames = files.compactMap { NSImage(contentsOf: $0) }
        NSLog("NotchPet: loaded \(frames.count) animation frames")
    }

    // MARK: - Frame Animation (idle/burst cycle)

    /// Start the idle/burst cycle: sit still for a few seconds, play one animation loop, repeat.
    func startIdleCycle() {
        stopAllAnimations()
        // Show first frame (standing still)
        if !frames.isEmpty {
            imageView.image = frames[0]
        }
        scheduleNextBurst()
    }

    private func scheduleNextBurst() {
        guard !usingPokemonSprite else { return }  // Don't animate frames when showing a Pokemon
        idleTimer?.invalidate()
        let wait = Double.random(in: 4.0...8.0)
        idleTimer = Timer.scheduledTimer(withTimeInterval: wait, repeats: false) { [weak self] _ in
            self?.playOneBurst()
        }
    }

    /// Play the animation frames once through, then return to idle.
    private func playOneBurst() {
        guard frames.count > 1 else { return }
        isAnimating = true
        currentFrameIndex = 0

        frameTimer?.invalidate()
        frameTimer = Timer.scheduledTimer(withTimeInterval: frameRate, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.currentFrameIndex += 1
            if self.currentFrameIndex >= self.frames.count {
                // Done — back to idle
                self.frameTimer?.invalidate()
                self.frameTimer = nil
                self.isAnimating = false
                self.imageView.image = self.frames[0]
                self.scheduleNextBurst()
            } else {
                self.imageView.image = self.frames[self.currentFrameIndex]
            }
        }
    }

    func startFrameAnimation() {
        startIdleCycle()
    }

    func stopFrameAnimation() {
        stopAllAnimations()
    }

    private func stopAllAnimations() {
        frameTimer?.invalidate()
        frameTimer = nil
        idleTimer?.invalidate()
        idleTimer = nil
        isAnimating = false
    }

    // MARK: - Position & Direction

    private func updatePetPosition() {
        let size = PetWindow.petSize
        let y = (bounds.height - size) / 2
        imageView.frame = NSRect(x: petLocalX, y: y, width: size, height: size)
    }

    func setPetLocalX(_ x: CGFloat) {
        petLocalX = x
        updatePetPosition()
    }

    func setDirection(_ dir: PetDirection) {
        direction = dir
        if dir == .left {
            // Flip horizontally
            imageView.layer?.setAffineTransform(CGAffineTransform(scaleX: -1, y: 1))
        } else {
            imageView.layer?.setAffineTransform(.identity)
        }
    }

    // MARK: - Running

    func startRunning(to targetX: CGFloat) {
        guard !isRunning else { return }
        isRunning = true
        runTarget = targetX

        // Set direction based on target
        if targetX > petLocalX {
            setDirection(.right)
        } else {
            setDirection(.left)
        }

        let speed: CGFloat = 1.5 // points per tick
        runTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }

            let dx = self.runTarget - self.petLocalX
            if abs(dx) < speed {
                self.petLocalX = self.runTarget
                self.updatePetPosition()
                self.stopRunning()
                return
            }

            self.petLocalX += dx > 0 ? speed : -speed
            self.petLocalX = max(self.minRunX, min(self.petLocalX, self.maxRunX))
            self.updatePetPosition()
        }
    }

    func stopRunning() {
        isRunning = false
        runTimer?.invalidate()
        runTimer = nil
    }

    func returnHome() {
        startRunning(to: homeX)
    }

    // MARK: - Pokemon sprite mode

    /// Switch to displaying a static Pokemon sprite instead of animation frames
    private var usingPokemonSprite = false

    func setPokemonSprite(_ id: String, shiny: Bool = false) {
        usingPokemonSprite = true
        stopAllAnimations()
        if let img = PetCollection.spriteImage(for: id, shiny: shiny) {
            imageView.image = img
        }
        // Start a gentle idle bounce for the static sprite
        startStaticIdleAnimation()
    }

    private func startStaticIdleAnimation() {
        // Subtle breathing effect for static sprites
        let breathe = CABasicAnimation(keyPath: "transform.scale")
        breathe.fromValue = 1.0
        breathe.toValue = 1.04
        breathe.duration = 2.5
        breathe.autoreverses = true
        breathe.repeatCount = .infinity
        breathe.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        imageView.layer?.add(breathe, forKey: "breathe")
    }

    // MARK: - Eating animation

    func playEatAnimation() {
        // Quick chomp: scale up, squish, bounce back
        let eat = CAKeyframeAnimation(keyPath: "transform.scale")
        eat.values = [1.0, 1.2, 0.85, 1.05, 1.0]
        eat.keyTimes = [0, 0.2, 0.5, 0.8, 1.0]
        eat.duration = 0.4
        imageView.layer?.add(eat, forKey: "eat")

        // Also do a little hop
        playBounce()
    }

    // MARK: - Bounce

    /// Small hop — the pet jumps up slightly and comes back down
    func playBounce() {
        let bounce = CAKeyframeAnimation(keyPath: "transform.translation.y")
        bounce.values = [0, 4, 0]
        bounce.keyTimes = [0, 0.4, 1.0]
        bounce.duration = 0.25
        bounce.timingFunction = CAMediaTimingFunction(name: .easeOut)
        imageView.layer?.add(bounce, forKey: "bounce")
    }

    /// Start occasional random bouncing (every 8-15 seconds)
    private var bounceTimer: Timer?

    func startRandomBouncing() {
        scheduleNextBounce()
    }

    private func scheduleNextBounce() {
        bounceTimer?.invalidate()
        let wait = Double.random(in: 8.0...15.0)
        bounceTimer = Timer.scheduledTimer(withTimeInterval: wait, repeats: false) { [weak self] _ in
            self?.playBounce()
            self?.scheduleNextBounce()
        }
    }

    func stopRandomBouncing() {
        bounceTimer?.invalidate()
        bounceTimer = nil
    }

    // MARK: - Legacy animation support

    func squish() {
        let squish = CAKeyframeAnimation(keyPath: "transform.scale.y")
        squish.values = [1.0, 0.7, 1.1, 1.0]
        squish.keyTimes = [0, 0.3, 0.7, 1.0]
        squish.duration = 0.3
        imageView.layer?.add(squish, forKey: "squish")
    }

    func setAnimationSpeed(_ speed: AnimationSpeed) {
        // Just restart the idle cycle — frameRate is fixed, but we could adjust later
        startIdleCycle()
    }

    // MARK: - Mouse event forwarding

    override func mouseDown(with event: NSEvent) {
        interaction?.handleMouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        interaction?.handleMouseDragged(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        interaction?.handleMouseUp(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        interaction?.handleRightMouseDown(with: event)
    }
}
