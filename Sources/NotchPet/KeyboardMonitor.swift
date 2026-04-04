import Foundation
import CoreGraphics

// MARK: - Typing State

enum TypingState {
    case idle    // no typing for 10+ seconds
    case typing  // actively typing
    case fast    // >80 WPM
    case burst   // >100 WPM
}

// MARK: - Keyboard Monitor

final class KeyboardMonitor {

    var onKeypress: (() -> Void)?
    var onWordBoundary: (() -> Void)?
    var onWPMUpdate: ((Double) -> Void)?
    var onTypingStateChanged: ((TypingState) -> Void)?

    fileprivate var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var keypressTimestamps: [Date] = []
    private var lastKeypressTime: Date?
    private var currentState: TypingState = .idle
    private var wpmTimer: Timer?
    private var retryTimer: Timer?

    private static let rollingWindowSeconds: TimeInterval = 60
    private static let wpmInterval: TimeInterval = 2
    private static let idleThreshold: TimeInterval = 10
    private static let focusAlertThreshold: TimeInterval = 600  // 10 minutes

    // MARK: - Start / Stop

    func start() {
        guard eventTap == nil else { return }
        if !createEventTap() {
            print("[KeyboardMonitor] Accessibility permission not granted. Retrying every 5 seconds...")
            retryTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] timer in
                guard let self = self else { timer.invalidate(); return }
                if self.createEventTap() {
                    timer.invalidate()
                    self.retryTimer = nil
                    print("[KeyboardMonitor] Event tap created successfully after retry.")
                }
            }
        }
        startWPMTimer()
    }

    func stop() {
        retryTimer?.invalidate()
        retryTimer = nil
        wpmTimer?.invalidate()
        wpmTimer = nil

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
            eventTap = nil
            runLoopSource = nil
        }

        keypressTimestamps.removeAll()
        lastKeypressTime = nil
        updateState(.idle)
    }

    // MARK: - Event Tap

    @discardableResult
    private func createEventTap() -> Bool {
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: keyboardCallback,
            userInfo: selfPtr
        ) else {
            return false
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("[KeyboardMonitor] Event tap active.")
        return true
    }

    // MARK: - Keypress Handling

    fileprivate func handleKeyDown(keyCode: Int64) {
        let now = Date()
        lastKeypressTime = now
        keypressTimestamps.append(now)

        onKeypress?()

        // Space (49), Return (36), Enter/numpad (76)
        if keyCode == 49 || keyCode == 36 || keyCode == 76 {
            onWordBoundary?()
        }
    }

    // MARK: - WPM Calculation

    private func startWPMTimer() {
        wpmTimer?.invalidate()
        wpmTimer = Timer.scheduledTimer(
            withTimeInterval: Self.wpmInterval,
            repeats: true
        ) { [weak self] _ in
            self?.recalculate()
        }
    }

    private func recalculate() {
        let now = Date()

        // Prune timestamps older than the rolling window
        let cutoff = now.addingTimeInterval(-Self.rollingWindowSeconds)
        keypressTimestamps.removeAll { $0 < cutoff }

        // WPM: characters in last 60s / 5 chars per word / 1 minute
        let count = Double(keypressTimestamps.count)
        let wpm = count / 5.0

        onWPMUpdate?(wpm)

        // Determine typing state
        let timeSinceLastKey = lastKeypressTime.map { now.timeIntervalSince($0) } ?? .infinity

        if timeSinceLastKey > Self.idleThreshold {
            updateState(.idle)
        } else if wpm > 100 {
            updateState(.burst)
        } else if wpm > 80 {
            updateState(.fast)
        } else {
            updateState(.typing)
        }
    }

    // MARK: - State Management

    private func updateState(_ newState: TypingState) {
        guard newState != currentState else { return }
        let oldState = currentState
        currentState = newState

        onTypingStateChanged?(newState)

        // Focus alert: was actively typing, now idle for 10+ minutes
        // The timer-based recalculate handles ongoing checks; the
        // AppDelegate can inspect the idle duration via the callback.
        if newState == .idle && oldState != .idle {
            // Schedule a one-shot check for the 10-minute focus alert
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.focusAlertThreshold) { [weak self] in
                guard let self = self, self.currentState == .idle else { return }
                // Still idle after 10 minutes — fire the state change again
                // so the AppDelegate can trigger a focus alert animation
                self.onTypingStateChanged?(.idle)
            }
        }
    }

    deinit {
        stop()
    }
}

// Make TypingState Equatable so we can compare states
extension TypingState: Equatable {}

// MARK: - C Callback

private func keyboardCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    // If the tap is disabled by the system, re-enable it
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let userInfo = userInfo {
            let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(userInfo).takeUnretainedValue()
            if let tap = monitor.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
        }
        return Unmanaged.passUnretained(event)
    }

    guard type == .keyDown, let userInfo = userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(userInfo).takeUnretainedValue()
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    monitor.handleKeyDown(keyCode: keyCode)

    return Unmanaged.passUnretained(event)
}
