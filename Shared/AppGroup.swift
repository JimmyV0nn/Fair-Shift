import Foundation

// the app, widget and share extension all talk to each other through this one container
enum AppGroup {
    static let identifier = "group.au.edu.au.FairShift"

    // only nil if the App Group entitlement is missing
    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    static var userDefaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}
