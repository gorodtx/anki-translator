import Foundation

/// What the shell knows about the settings the backend holds, and what to do when a load
/// arrives. Kept apart from the model so the rules can be tested without a backend.
///
/// The two rules that matter:
/// - Nothing is saved before the first load: until then the shell holds defaults, and
///   sending them would overwrite the user's real configuration.
/// - A change the backend has not taken (still waiting, in flight, or refused) is newer
///   than what a load brings, so the load must not put the old values back. A refused
///   one is sent again instead.
public struct SettingsSync<Value: Equatable>: Equatable {
    /// What the backend is known to hold: loaded from it, or saved to it. Nil until the
    /// first load.
    public private(set) var synced: Value?
    /// The last save of a change failed and nothing has been saved since.
    public private(set) var saveFailed = false

    public init() {}

    /// Whether the backend's values have been read at least once.
    public var isLoaded: Bool { synced != nil }

    /// What a load does with the local values.
    public enum LoadOutcome: Equatable {
        /// Take the loaded values; they are what the backend holds.
        case adopt
        /// Keep the local values: a save is waiting or on its way.
        case keepLocal
        /// Keep the local values and send them again: the last save failed.
        case retrySave
    }

    /// Whether a change to `local` should be sent.
    public func needsSave(_ local: Value) -> Bool {
        guard let synced else { return false }
        return local != synced
    }

    public mutating func loaded(_ value: Value, local: Value, saveInProgress: Bool) -> LoadOutcome {
        if saveInProgress { return .keepLocal }
        if saveFailed, synced != nil, local != synced {
            // The backend still answers with what it had before the refused change.
            return .retrySave
        }
        synced = value
        saveFailed = false
        return .adopt
    }

    public mutating func saved(_ value: Value) {
        synced = value
        saveFailed = false
    }

    public mutating func saveDidFail() {
        saveFailed = true
    }
}
