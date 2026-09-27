import Foundation

/// What the user reads when a request to the backend fails.
///
/// The backend and the IPC client describe failures for a log ("Backend is not
/// connected.", "No history entry 42.", "invalid_params"). Every window shows them through
/// this one mapping, so the same fault reads the same everywhere and in the app's own
/// voice; the raw text goes to the log instead.
public enum ErrorWording {
    /// The sentence for an IPC error with this code and raw message.
    public static func sentence(code: String, message raw: String) -> String {
        let message = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        switch code {
        case "disconnected", "write_failed":
            return backendNotRunning
        case "timeout":
            return "Translator’s backend didn’t answer in time."
        case "no_active_entry":
            return noActiveEntry(message)
        case "not_ready":
            return notReady(message)
        case "anki_error":
            // Anki's own words are about the user's collection, and they mean something.
            return message.isEmpty ? "Anki didn’t answer." : message
        case "unknown_method":
            return "This version of Translator’s backend can’t do that."
        case "bad_request", "invalid_params":
            return "Translator’s backend didn’t understand the request."
        case "internal":
            return "Something went wrong in Translator’s backend."
        default:
            return message.isEmpty ? "Something went wrong." : message
        }
    }

    /// Said when the backend is not there to ask.
    public static let backendNotRunning = "Translator’s backend isn’t running."
    /// Said when a lookup was waiting and the connection went away.
    public static let backendStopped = "Translator’s backend stopped responding."
    /// Said when a request was sent and no usable answer came back.
    public static let backendNoAnswer = "Translator’s backend didn’t answer."

    private static func noActiveEntry(_ message: String) -> String {
        if message.hasPrefix("No history entry") { return "This entry is no longer in History." }
        if message == "Entry has no translation." { return "This entry has no translation to show." }
        if message == "Prepare an upsert first." { return "The note isn’t ready. Open Add to Anki again." }
        return "There’s no translation to use. Look up a word first."
    }

    private static func notReady(_ message: String) -> String {
        if message.localizedCaseInsensitiveContains("deck or model") {
            return "Choose a deck and a note type in Settings > Anki first."
        }
        if message.localizedCaseInsensitiveContains("downloads are not available") {
            return "Downloads aren’t available in this copy of Translator."
        }
        return "Translator’s backend isn’t ready yet."
    }
}
