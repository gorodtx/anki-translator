import Foundation

/// An opt-in test domain keeps first-run and hot-key probes out of the user's defaults.
enum AppDefaults {
    private static let isolatedStore: UserDefaults? = {
        if let suite = ProcessInfo.processInfo.environment["TRANSLATOR_DEFAULTS_SUITE"],
           !suite.isEmpty, let isolated = UserDefaults(suiteName: suite) {
            return isolated
        }
        return nil
    }()
    static let store: UserDefaults = isolatedStore ?? .standard
    static var isIsolated: Bool { isolatedStore != nil }
}
