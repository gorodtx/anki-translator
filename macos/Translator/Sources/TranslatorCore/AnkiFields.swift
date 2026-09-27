import Foundation

/// Whether the configured field names match the note type Anki actually has.
///
/// Getting one wrong is invisible in Settings and fails much later, when a card is added,
/// far from the setting that caused it. The rule that matters here is a negative one: an
/// empty field list means there is nothing to compare against — the note type does not
/// exist, or Anki is closed, and both answer alike — so flagging every name at that point
/// would paint a correct configuration red. That is why the decision lives in a pure
/// function instead of in the view.
public struct AnkiFieldIssue: Equatable, Sendable, Identifiable {
    public let configured: String
    /// A field the note type does have that differs only in case or surrounding space,
    /// when there is one. Then the fix is obvious rather than a hunt.
    public let suggestion: String?

    public var id: String { configured }

    public init(configured: String, suggestion: String? = nil) {
        self.configured = configured
        self.suggestion = suggestion
    }
}

public enum AnkiFieldCheck {
    /// Anki's own refusal, plus what it means here.
    ///
    /// A mistyped field name makes Anki answer "cannot create note because it is empty",
    /// which sends the user to look at the card — the note is not empty, the name is
    /// wrong. Both halves are known on this side, so the message says both. With nothing
    /// known, Anki's words stand alone rather than being decorated with a guess.
    public static func explain(failure: String, issues: [AnkiFieldIssue]) -> String {
        guard !issues.isEmpty else { return failure }
        let names = issues.map { "“\($0.configured)”" }.joined(separator: ", ")
        let plural = issues.count == 1 ? "no" : "none of"
        let suggestion = issues.compactMap(\.suggestion).first
        let fix = suggestion.map { " Anki has “\($0)”." } ?? ""
        return "\(failure) The note type has \(plural) \(names).\(fix) Fix the field mapping in Settings."
    }

    /// Configured names the note type does not have. Empty when nothing can be concluded.
    public static func issues(configured: [String], modelFields: [String]) -> [AnkiFieldIssue] {
        // Nothing to compare against is not the same as everything being wrong.
        guard !modelFields.isEmpty else { return [] }

        let known = Set(modelFields.map { $0.trimmingCharacters(in: .whitespaces) })
        // A name differing only in case is the common mistake, and worth naming outright.
        var nearby: [String: String] = [:]
        for field in modelFields {
            let key = field.trimmingCharacters(in: .whitespaces).lowercased()
            if nearby[key] == nil { nearby[key] = field }
        }

        var reported = Set<String>()
        return configured.compactMap { name in
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            // An empty mapping means "leave this field alone", which the backend honours
            // by dropping it. Not a mistake, so not a warning.
            guard !trimmed.isEmpty, !known.contains(trimmed) else { return nil }
            guard reported.insert(trimmed).inserted else { return nil }
            return AnkiFieldIssue(configured: name, suggestion: nearby[trimmed.lowercased()])
        }
    }
}

/// What is still missing before a note can be added at all.
///
/// The backend refuses `anki.prepare_upsert` with one generic "not configured" error
/// unless the deck, the note type and all five field names are set (`is_config_ready` in
/// `anki_flow.py`). The Add to Anki window has to say which of those is missing and where
/// to fix it, so the same rule is stated here, where it is tested.
public enum AnkiSetupGap: Equatable, Sendable {
    case deck
    case noteType
    case fieldNames

    public static func gaps(in settings: AnkiSettings) -> [AnkiSetupGap] {
        let blank = { (value: String) in value.trimmingCharacters(in: .whitespaces).isEmpty }
        var gaps: [AnkiSetupGap] = []
        if blank(settings.deck) { gaps.append(.deck) }
        if blank(settings.model) { gaps.append(.noteType) }
        let fields = settings.fields
        if [fields.word, fields.translation, fields.exampleEn, fields.definitionsEn, fields.image].contains(where: blank) {
            gaps.append(.fieldNames)
        }
        return gaps
    }

    /// One sentence saying what to do in Settings, or nil when nothing is missing.
    public static func instruction(for gaps: [AnkiSetupGap]) -> String? {
        if gaps == [.fieldNames] { return "Fill in the field names in Settings." }
        let items = gaps.map { gap in
            switch gap {
            case .deck: return "a deck"
            case .noteType: return "a note type"
            case .fieldNames: return "field names"
            }
        }
        guard let last = items.last else { return nil }
        let list = items.count == 1 ? last : items.dropLast().joined(separator: ", ") + " and " + last
        return "Choose \(list) in Settings."
    }
}

/// The lookup an Add to Anki note is prepared from.
///
/// The backend keeps one prepared note, and it belongs to the current lookup: a lookup of
/// another word, opening a history entry, or closing the session (Esc or a click outside
/// the popup) drops it, and adding then fails with "Prepare an upsert first.". The window
/// compares what it prepared from with what the app holds now.
public struct AnkiNoteSource: Equatable, Sendable {
    /// The looked-up text, as the Word row shows it.
    public var text: String
    public var requestId: Int
    /// How many times the backend session has been closed so far.
    public var closedSessions: Int

    public init(text: String, requestId: Int, closedSessions: Int) {
        self.text = text
        self.requestId = requestId
        self.closedSessions = closedSessions
    }
}

/// What Add to Anki does when the lookup under it changes while it is open.
public enum AnkiSheetFollowUp: Equatable, Sendable {
    /// Still the lookup it was prepared from.
    case keep
    /// A new lookup is still translating; prepare once it has finished.
    case wait
    /// A new lookup finished with something to add: prepare the note from it.
    case prepare
    /// Nothing is left to add from: the session was closed, or the new lookup has no
    /// result. The window closes rather than offer an Add that must fail.
    case close

    public static func after(
        preparedFrom prepared: AnkiNoteSource?,
        now: AnkiNoteSource,
        loading: Bool,
        canAdd: Bool
    ) -> AnkiSheetFollowUp {
        // Not prepared yet: the first preparation reads the lookup as it is then.
        guard let prepared else { return .keep }
        // A closed session has no active request, and the backend drops a preparation
        // made for none without answering.
        if now.closedSessions != prepared.closedSessions { return .close }
        // The same word looked up again reuses the entry and keeps the prepared note.
        if now.text == prepared.text, now.requestId == prepared.requestId { return .keep }
        if loading { return .wait }
        return canAdd ? .prepare : .close
    }
}
