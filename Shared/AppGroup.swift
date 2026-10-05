import Foundation

// the app, the widget and the share extension all talk through this one container
enum AppGroup {
    static let identifier = "group.au.edu.au.FairShift"

    // nil only if the App Group entitlement is missing (e.g. a build signed without it)
    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    static var userDefaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}
