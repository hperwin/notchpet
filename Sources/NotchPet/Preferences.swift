import Foundation
import ServiceManagement

final class Preferences {
    static let shared = Preferences()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let windowX = "notchpet.windowX"
        static let hasSetPosition = "notchpet.hasSetPosition"
        static let animationSpeed = "notchpet.animationSpeed"
        static let autoLaunch = "notchpet.autoLaunch"
        static let hasLaunchedBefore = "notchpet.hasLaunchedBefore"
        static let berriesEnabled = "notchpet.berriesEnabled"
    }

    var savedWindowX: CGFloat? {
        get {
            guard defaults.bool(forKey: Keys.hasSetPosition) else { return nil }
            return defaults.double(forKey: Keys.windowX)
        }
        set {
            if let value = newValue {
                defaults.set(value, forKey: Keys.windowX)
                defaults.set(true, forKey: Keys.hasSetPosition)
            } else {
                defaults.removeObject(forKey: Keys.windowX)
                defaults.set(false, forKey: Keys.hasSetPosition)
            }
        }
    }

    var animationSpeed: AnimationSpeed {
        get {
            let raw = defaults.integer(forKey: Keys.animationSpeed)
            return AnimationSpeed(rawValue: raw) ?? .normal
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.animationSpeed)
        }
    }

    var isAutoLaunchEnabled: Bool {
        get { defaults.bool(forKey: Keys.autoLaunch) }
        set {
            defaults.set(newValue, forKey: Keys.autoLaunch)
            if newValue {
                try? SMAppService.mainApp.register()
            } else {
                try? SMAppService.mainApp.unregister()
            }
        }
    }

    var hasLaunchedBefore: Bool {
        get { defaults.bool(forKey: Keys.hasLaunchedBefore) }
        set { defaults.set(newValue, forKey: Keys.hasLaunchedBefore) }
    }

    var berriesEnabled: Bool {
        get {
            // Default to true if never set
            if defaults.object(forKey: Keys.berriesEnabled) == nil { return true }
            return defaults.bool(forKey: Keys.berriesEnabled)
        }
        set { defaults.set(newValue, forKey: Keys.berriesEnabled) }
    }

    private init() {}
}

enum AnimationSpeed: Int {
    case slow = 0
    case normal = 1
    case fast = 2

    var multiplier: Double {
        switch self {
        case .slow: return 1.5
        case .normal: return 1.0
        case .fast: return 0.6
        }
    }

    var label: String {
        switch self {
        case .slow: return "Slow"
        case .normal: return "Normal"
        case .fast: return "Fast"
        }
    }
}
