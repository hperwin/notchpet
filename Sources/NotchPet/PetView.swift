import AppKit
import QuartzCore

final class PetView: NSView {
    let imageView = NSImageView()
    weak var interaction: PetInteraction?
    private var blinkTimer: Timer?
    private var animationSpeed: AnimationSpeed = Preferences.shared.animationSpeed

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
        layer?.backgroundColor = NSColor.black.cgColor

        guard let image = loadAndProcessImage() else {
            NSLog("NotchPet: Failed to load blob.png")
            return
        }

        imageView.image = image
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)

        let petSize: CGFloat = 28
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: petSize),
            imageView.heightAnchor.constraint(equalToConstant: petSize),
        ])

        startIdleAnimations()
    }

    private func loadAndProcessImage() -> NSImage? {
        guard let url = Bundle.module.url(forResource: "blob", withExtension: "png"),
              let nsImage = NSImage(contentsOf: url),
              let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let cgImage = bitmap.cgImage
        else { return nil }

        let width = cgImage.width
        let height = cgImage.height
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
        ) else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Make near-white pixels transparent (threshold: RGB all > 220)
        let threshold: UInt8 = 220
        for i in stride(from: 0, to: pixelData.count, by: bytesPerPixel) {
            let r = pixelData[i]
            let g = pixelData[i + 1]
            let b = pixelData[i + 2]
            if r > threshold && g > threshold && b > threshold {
                pixelData[i] = 0     // R
                pixelData[i + 1] = 0 // G
                pixelData[i + 2] = 0 // B
                pixelData[i + 3] = 0 // A
            }
        }

        guard let processedCGImage = context.makeImage() else { return nil }
        return NSImage(cgImage: processedCGImage, size: NSSize(width: width, height: height))
    }

    func startIdleAnimations() {
        imageView.layer?.removeAllAnimations()
        blinkTimer?.invalidate()

        let speed = animationSpeed.multiplier

        // Breathing
        let breathe = CABasicAnimation(keyPath: "transform.scale")
        breathe.fromValue = 1.0
        breathe.toValue = 1.05
        breathe.duration = 3.0 * speed
        breathe.autoreverses = true
        breathe.repeatCount = .infinity
        breathe.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        imageView.layer?.add(breathe, forKey: "breathe")

        // Wiggle
        let wiggle = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        let angle = CGFloat.pi / 60  // ~3 degrees
        wiggle.values = [0, angle, 0, -angle, 0]
        wiggle.keyTimes = [0, 0.25, 0.5, 0.75, 1.0]
        wiggle.duration = 5.0 * speed
        wiggle.repeatCount = .infinity
        wiggle.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        imageView.layer?.add(wiggle, forKey: "wiggle")

        // Blink
        scheduleBlink()
    }

    private func scheduleBlink() {
        let interval = Double.random(in: 4.0...6.0) * animationSpeed.multiplier
        blinkTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.performBlink()
        }
    }

    private func performBlink() {
        let blink = CAKeyframeAnimation(keyPath: "transform.scale.y")
        blink.values = [1.0, 0.1, 1.0]
        blink.keyTimes = [0, 0.5, 1.0]
        blink.duration = 0.15 * animationSpeed.multiplier
        imageView.layer?.add(blink, forKey: "blink")
        scheduleBlink()
    }

    func squish() {
        let squish = CAKeyframeAnimation(keyPath: "transform.scale.y")
        squish.values = [1.0, 0.7, 1.1, 1.0]
        squish.keyTimes = [0, 0.3, 0.7, 1.0]
        squish.duration = 0.3 * animationSpeed.multiplier
        imageView.layer?.add(squish, forKey: "squish")
    }

    func setAnimationSpeed(_ speed: AnimationSpeed) {
        animationSpeed = speed
        startIdleAnimations()
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
