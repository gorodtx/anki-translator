import Foundation
import Testing
@testable import TranslatorCore

/// A field name Anki does not have is invisible in Settings and fails when a card is
/// added — far from the setting that caused it. These cover what may and may not be
/// concluded from the note type's answer.
@Suite struct AnkiFieldCheckTests {
    private let model = ["Word", "Translation", "Example", "Definition", "Image"]

    @Test func namesTheNoteTypeHasAreNotFlagged() {
        #expect(AnkiFieldCheck.issues(configured: ["Word", "Image"], modelFields: model).isEmpty)
    }

    /// The whole point: an empty answer means the question was not settled. A closed Anki
    /// and a note type that does not exist both answer this way, and flagging every name
    /// would paint a correct configuration red.
    @Test func anEmptyModelFlagsNothing() {
        #expect(AnkiFieldCheck.issues(configured: ["word", "nonsense"], modelFields: []).isEmpty)
    }

    /// The common mistake, and the one worth naming outright.
    @Test func aCaseMismatchSuggestsTheRealName() {
        let issues = AnkiFieldCheck.issues(configured: ["word"], modelFields: model)
        #expect(issues.count == 1)
        #expect(issues[0].configured == "word")
        #expect(issues[0].suggestion == "Word")
    }

    @Test func anUnrelatedNameIsFlaggedWithoutASuggestion() {
        let issues = AnkiFieldCheck.issues(configured: ["Meaning"], modelFields: model)
        #expect(issues.map(\.configured) == ["Meaning"])
        #expect(issues[0].suggestion == nil)
    }

    /// The backend drops an empty mapping, which is how a field is left alone. Reporting
    /// it would invent a mistake the user did not make.
    @Test func anEmptyMappingIsNotAMistake() {
        #expect(AnkiFieldCheck.issues(configured: ["", "   "], modelFields: model).isEmpty)
    }

    /// Anki matches exactly and the backend strips, so surrounding space is harmless.
    @Test func surroundingSpaceIsIgnored() {
        #expect(AnkiFieldCheck.issues(configured: ["  Word  "], modelFields: model).isEmpty)
    }

    @Test func theSameWrongNameIsReportedOnce() {
        let issues = AnkiFieldCheck.issues(configured: ["Nope", "Nope"], modelFields: model)
        #expect(issues.count == 1)
    }
}

/// Decoded from what the backend actually sent, copied from a live run: a decoder that
/// has drifted answers with an empty list, which this UI is required to read as "nothing
/// to compare against" — so a silent drift would look exactly like a healthy unknown.
@Suite struct AnkiModelFieldsWireTests {
    @Test func aReachableAnkiDecodesItsFields() throws {
        let json = #"{"fields": ["word", "translation", "example_en", "definitions_en", "image"], "error": null}"#
        let answer = try IPCCoding.decoder.decode(AnkiModelFields.self, from: Data(json.utf8))
        #expect(answer.fields.count == 5)
        #expect(answer.fields.first == "word")
        #expect(answer.error == nil)
        #expect(AnkiFieldCheck.issues(
            configured: ["word", "translation", "example_en", "definitions_en", "image"],
            modelFields: answer.fields
        ).isEmpty, "the shipped defaults match the note type this backend creates")
    }

    @Test func aClosedAnkiDecodesItsReason() throws {
        let json = #"""
        {"fields": [], "error": "AnkiConnect error: Cannot connect to host 127.0.0.1:8765 ssl:default [Connect call failed ('127.0.0.1', 8765)]"}
        """#
        let answer = try IPCCoding.decoder.decode(AnkiModelFields.self, from: Data(json.utf8))
        #expect(answer.fields.isEmpty)
        #expect(answer.error?.contains("Cannot connect") == true)
        // Nothing may be flagged from this, however the names are configured.
        #expect(AnkiFieldCheck.issues(configured: ["Nope"], modelFields: answer.fields).isEmpty)
    }

    /// An unknown note type answers exactly like one with no fields — empty, no error —
    /// so neither may produce a warning.
    @Test func anUnknownNoteTypeIsIndistinguishableAndSilent() throws {
        let json = #"{"fields": [], "error": null}"#
        let answer = try IPCCoding.decoder.decode(AnkiModelFields.self, from: Data(json.utf8))
        #expect(answer.fields.isEmpty)
        #expect(answer.error == nil)
        #expect(AnkiFieldCheck.issues(configured: ["word"], modelFields: answer.fields).isEmpty)
    }
}

/// What the user reads when Anki refuses the card. Measured from a live run against a
/// stand-in that fails the way the real server does: a mistyped first field name makes
/// Anki answer "cannot create note because it is empty", which is true of the note and
/// useless about the cause.
@Suite struct AnkiFailureExplanationTests {
    private let refusal = "cannot create note because it is empty"

    @Test func aMistypedNameIsNamedAlongsideAnkisWords() {
        let text = AnkiFieldCheck.explain(
            failure: refusal,
            issues: AnkiFieldCheck.issues(
                configured: ["Woord", "translation"],
                modelFields: ["word", "translation", "example_en"]
            )
        )
        #expect(text.hasPrefix(refusal), "Anki's own words come first")
        #expect(text.contains("Woord"))
        #expect(text.contains("Settings"))
        #expect(!text.contains("translation"), "a name that is fine is not mentioned")
    }

    /// The common mistake deserves the answer, not just the complaint.
    @Test func aCaseMismatchPointsAtTheRealName() {
        let text = AnkiFieldCheck.explain(
            failure: refusal,
            issues: AnkiFieldCheck.issues(configured: ["word"], modelFields: ["Word"])
        )
        #expect(text.contains("Anki has “Word”"))
    }

    /// With nothing known — Anki closed, note type absent, section never opened — the
    /// refusal stands alone rather than being decorated with a guess.
    @Test func withNothingKnownAnkisWordsStandAlone() {
        #expect(AnkiFieldCheck.explain(failure: refusal, issues: []) == refusal)
    }

    @Test func severalWrongNamesReadAsPlural() {
        let text = AnkiFieldCheck.explain(
            failure: refusal,
            issues: AnkiFieldCheck.issues(configured: ["A", "B"], modelFields: ["word"])
        )
        #expect(text.contains("none of"))
        #expect(text.contains("“A”, “B”"))
    }
}

/// The Add to Anki window names what is missing instead of repeating the backend's
/// generic "not configured". The rule must match `is_config_ready` exactly, or the window
/// would offer to add a note the backend then refuses.
@Suite struct AnkiSetupGapTests {
    private func settings(
        deck: String = "English",
        model: String = "Translator",
        fields: AnkiFieldMapping = AnkiFieldMapping()
    ) -> AnkiSettings {
        AnkiSettings(deck: deck, model: model, fields: fields)
    }

    @Test func aCompleteConfigurationHasNoGaps() {
        #expect(AnkiSetupGap.gaps(in: settings()).isEmpty)
        #expect(AnkiSetupGap.instruction(for: []) == nil)
    }

    /// What a first run looks like: the backend's defaults leave both empty.
    @Test func aFreshConfigurationMissesDeckAndNoteType() {
        let gaps = AnkiSetupGap.gaps(in: settings(deck: "", model: ""))
        #expect(gaps == [.deck, .noteType])
        #expect(AnkiSetupGap.instruction(for: gaps) == "Choose a deck and a note type in Settings.")
    }

    @Test func whitespaceCountsAsMissing() {
        #expect(AnkiSetupGap.gaps(in: settings(deck: "  ")) == [.deck])
    }

    /// All five field names are required, the image field included.
    @Test func anyEmptyFieldNameIsAGap() {
        var fields = AnkiFieldMapping()
        fields.image = ""
        let gaps = AnkiSetupGap.gaps(in: settings(fields: fields))
        #expect(gaps == [.fieldNames])
        #expect(AnkiSetupGap.instruction(for: gaps) == "Fill in the field names in Settings.")
    }

    @Test func everyGapReadsAsOneSentence() {
        let gaps = AnkiSetupGap.gaps(in: settings(deck: "", model: "", fields: AnkiFieldMapping(word: "")))
        #expect(gaps == [.deck, .noteType, .fieldNames])
        #expect(AnkiSetupGap.instruction(for: gaps) == "Choose a deck, a note type and field names in Settings.")
    }
}

/// Add to Anki is prepared from one lookup, and the backend drops that preparation when
/// the lookup changes: the window must follow rather than offer an Add that fails.
@Suite struct AnkiSheetFollowUpTests {
    private let bank = AnkiNoteSource(text: "bank", requestId: 4, closedSessions: 1)

    private func after(_ now: AnkiNoteSource, loading: Bool = false, canAdd: Bool = true) -> AnkiSheetFollowUp {
        AnkiSheetFollowUp.after(preparedFrom: bank, now: now, loading: loading, canAdd: canAdd)
    }

    @Test func theSameLookupKeepsTheNote() {
        #expect(after(bank) == .keep)
    }

    @Test func nothingPreparedYetLeavesItToTheFirstPreparation() {
        #expect(AnkiSheetFollowUp.after(preparedFrom: nil, now: bank, loading: true, canAdd: false) == .keep)
    }

    /// The reported case: "went" looked up while the window was open for "bank".
    @Test func aNewWordThatFinishedIsPrepared() {
        #expect(after(AnkiNoteSource(text: "went", requestId: 5, closedSessions: 1)) == .prepare)
    }

    @Test func aNewWordStillTranslatingIsWaitedFor() {
        let went = AnkiNoteSource(text: "went", requestId: 5, closedSessions: 1)
        #expect(after(went, loading: true, canAdd: false) == .wait)
    }

    /// Opening the same word from History is a new request, and drops the note as well.
    @Test func aNewRequestForTheSameWordIsPrepared() {
        #expect(after(AnkiNoteSource(text: "bank", requestId: 6, closedSessions: 1)) == .prepare)
    }

    @Test func aNewLookupWithNothingToAddCloses() {
        #expect(after(AnkiNoteSource(text: "qwzxv", requestId: 5, closedSessions: 1), canAdd: false) == .close)
    }

    /// Opened before the lookup finished: prepared from the final result once it is in.
    @Test func aNotePreparedWhileTranslatingIsPreparedAgainOnceFinished() {
        let early = AnkiNoteSource(text: "bank", requestId: 4, closedSessions: 1, finished: false)
        let still = AnkiSheetFollowUp.after(preparedFrom: early, now: early, loading: true, canAdd: true)
        let done = AnkiSheetFollowUp.after(preparedFrom: early, now: bank, loading: false, canAdd: true)
        let empty = AnkiSheetFollowUp.after(preparedFrom: early, now: bank, loading: false, canAdd: false)
        #expect(still == .keep)
        #expect(done == .prepare)
        #expect(empty == .close)
    }

    /// Esc on the popup of a later lookup closes the session, and the note with it.
    @Test func aClosedSessionCloses() {
        #expect(after(AnkiNoteSource(text: "bank", requestId: 4, closedSessions: 2)) == .close)
        #expect(after(AnkiNoteSource(text: "went", requestId: 5, closedSessions: 2), loading: true) == .close)
    }
}

/// What Add to Anki says before adding with names the note type lacks: it names them, and
/// Anki's own spelling when the whole fix is a matter of capitals.
@Suite struct AnkiFieldWarningTests {
    private let model = ["Word", "Translation", "Example", "Definitions", "Image"]

    @Test func nothingWrongSaysNothing() {
        #expect(AnkiFieldCheck.warning(issues: [], noteType: "Basic") == nil)
    }

    @Test func oneNameWithItsSpelling() {
        let issues = AnkiFieldCheck.issues(configured: ["word", "Image"], modelFields: model)
        #expect(AnkiFieldCheck.warning(issues: issues, noteType: "Translator")
            == "“word” isn’t a field of Translator. Anki has “Word”.")
    }

    @Test func severalNamesAreListed() {
        let issues = AnkiFieldCheck.issues(configured: ["word", "translation", "image"], modelFields: model)
        #expect(AnkiFieldCheck.warning(issues: issues, noteType: "Translator")
            == "“word”, “translation” and “image” aren’t fields of Translator. Anki has “Word”, “Translation” and “Image”.")
    }

    /// A partial list of spellings would read as the whole fix.
    @Test func spellingsOnlyWhenEveryNameHasOne() {
        let issues = AnkiFieldCheck.issues(configured: ["word", "Meaning"], modelFields: model)
        #expect(AnkiFieldCheck.warning(issues: issues, noteType: "Basic")
            == "“word” and “Meaning” aren’t fields of Basic.")
    }

    @Test func aBlankNoteTypeIsNotQuoted() {
        let issues = [AnkiFieldIssue(configured: "Meaning")]
        #expect(AnkiFieldCheck.warning(issues: issues, noteType: " ")
            == "“Meaning” isn’t a field of the note type.")
    }
}
