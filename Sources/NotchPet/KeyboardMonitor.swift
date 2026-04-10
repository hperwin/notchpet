import Foundation
import CoreGraphics
import AppKit

// MARK: - Typing State

enum TypingState: Equatable {
    case idle
    case typing
    case fast
    case burst
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
    private var healthCheckTimer: Timer?
    private var totalKeypressCount: Int = 0
    private var watchdogAttempts: Int = 0
    private let startTime = Date()

    private static let rollingWindowSeconds: TimeInterval = 60
    private static let wpmInterval: TimeInterval = 2
    private static let idleThreshold: TimeInterval = 10

    // MARK: - Start / Stop

    func start() {
        guard eventTap == nil else { return }

        // Prompt for accessibility if not trusted — this also re-registers
        // the current binary with macOS, fixing stale permission issues
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        NSLog("NotchPet: Accessibility trusted = \(trusted)")

        if !createEventTap() {
            NSLog("NotchPet: Keyboard tap FAILED — no accessibility permission. Retrying every 5s...")
            NSLog("NotchPet: Grant access in System Settings → Privacy & Security → Accessibility")
            retryTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] timer in
                guard let self = self else { timer.invalidate(); return }
                if self.createEventTap() {
                    timer.invalidate()
                    self.retryTimer = nil
                    NSLog("NotchPet: Keyboard tap created after retry!")
                }
            }
        }

        startWPMTimer()
        startHealthCheck()
    }

    func stop() {
        retryTimer?.invalidate()
        retryTimer = nil
        wpmTimer?.invalidate()
        wpmTimer = nil
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil

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

    // MARK: - Event Tap Creation

    @discardableResult
    private func createEventTap() -> Bool {
        // Use passRetained so the pointer stays valid even if references change
        let selfPtr = Unmanaged.passRetained(self).toOpaque()

        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.tapDisabledByTimeout.rawValue)
            | (1 << CGEventType.tapDisabledByUserInput.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: keyboardCallback,
            userInfo: selfPtr
        ) else {
            // Release the retained reference since tap creation failed
            Unmanaged<KeyboardMonitor>.fromOpaque(selfPtr).release()
            return false
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        NSLog("NotchPet: Keyboard tap ACTIVE (listenOnly)")
        return true
    }

    // MARK: - Health Check (re-enable if macOS disabled the tap)

    private func startHealthCheck() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if let tap = self.eventTap {
                if !CGEvent.tapIsEnabled(tap: tap) {
                    NSLog("NotchPet: Keyboard tap was disabled by system — re-enabling")
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
            } else {
                NSLog("NotchPet: Keyboard tap lost — recreating")
                self.destroyAndRecreateTap()
            }

            // Watchdog: if we've never received a keypress after 10s, tap may be stale.
            // Destroy and recreate once. This handles the case where macOS grants
            // accessibility to the bundle ID but the binary signature changed.
            if self.eventTap != nil && self.totalKeypressCount == 0 && self.watchdogAttempts < 3 {
                let uptime = Date().timeIntervalSince(self.startTime)
                if uptime > 10 {
                    self.watchdogAttempts += 1
                    NSLog("NotchPet: Keyboard tap may be stale (0 events after \(Int(uptime))s) — recreating (attempt \(self.watchdogAttempts))")
                    self.destroyAndRecreateTap()
                }
            }
        }
    }

    private func destroyAndRecreateTap() {
        // Tear down existing tap completely
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
            eventTap = nil
            runLoopSource = nil
        }
        // Recreate fresh
        if createEventTap() {
            NSLog("NotchPet: Keyboard tap recreated successfully")
        } else {
            NSLog("NotchPet: Keyboard tap recreation FAILED")
        }
    }

    // MARK: - Keypress Handling

    fileprivate func handleKeyDown(keyCode: Int64) {
        let now = Date()
        lastKeypressTime = now
        keypressTimestamps.append(now)
        totalKeypressCount += 1

        // Log periodically so we can verify tracking
        if totalKeypressCount % 100 == 0 {
            NSLog("NotchPet: Keyboard — \(totalKeypressCount) keys tracked this session")
        }

        onKeypress?()

        // Space (49), Return (36), Enter/numpad (76)
        if keyCode == 49 || keyCode == 36 || keyCode == 76 {
            onWordBoundary?()
        }
    }

    // MARK: - WPM

    private func startWPMTimer() {
        wpmTimer?.invalidate()
        wpmTimer = Timer.scheduledTimer(withTimeInterval: Self.wpmInterval, repeats: true) { [weak self] _ in
            self?.recalculate()
        }
    }

    private func recalculate() {
        let now = Date()
        let cutoff = now.addingTimeInterval(-Self.rollingWindowSeconds)
        keypressTimestamps.removeAll { $0 < cutoff }

        let count = Double(keypressTimestamps.count)
        let wpm = count / 5.0

        onWPMUpdate?(wpm)

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

    // MARK: - State

    private func updateState(_ newState: TypingState) {
        guard newState != currentState else { return }
        currentState = newState
        onTypingStateChanged?(newState)
    }

    deinit {
        stop()
        // Release the retained self if tap exists
        // (normally stop() clears eventTap, but just in case)
    }
}

// MARK: - C Callback

private func keyboardCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo = userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(userInfo).takeUnretainedValue()

    // Re-enable tap if macOS disabled it
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = monitor.eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
            NSLog("NotchPet: Keyboard tap re-enabled after system disable")
        }
        return Unmanaged.passUnretained(event)
    }

    if type == .keyDown {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        // Dispatch to main thread to avoid threading issues
        DispatchQueue.main.async {
            monitor.handleKeyDown(keyCode: keyCode)
        }
    }

    return Unmanaged.passUnretained(event)
}
