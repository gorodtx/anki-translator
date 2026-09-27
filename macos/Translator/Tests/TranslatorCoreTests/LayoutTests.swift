import CoreGraphics
import Foundation
import Testing
@testable import TranslatorCore

@Suite struct KeyComboTests {
    @Test func defaultIsOptionCommandT() {
        let combo = KeyCombo.defaultCombo
        #expect(combo.displayString == "⌥⌘T")
        #expect(combo.isUsable)
    }

    @Test func modifiersRenderInCanonicalOrder() {
        let combo = KeyCombo(
            keyCode: 49,
            modifiers: KeyCombo.commandMask | KeyCombo.shiftMask | KeyCombo.optionMask | KeyCombo.controlMask
        )
        #expect(combo.displayString == "⌃⌥⇧⌘Space")
    }

    @Test func shiftAloneIsNotUsable() {
        #expect(!KeyCombo(keyCode: 17, modifiers: KeyCombo.shiftMask).isUsable)
        #expect(!KeyCombo(keyCode: 17, modifiers: 0).isUsable)
        #expect(KeyCombo(keyCode: 17, modifiers: KeyCombo.controlMask).isUsable)
    }

    @Test func unknownModifierBitsAreDropped() {
        let combo = KeyCombo(keyCode: 17, modifiers: KeyCombo.commandMask | 0x4000)
        #expect(combo.modifiers == KeyCombo.commandMask)
    }

    @Test func roundTripsThroughStorage() throws {
        let combo = KeyCombo(keyCode: 46, modifiers: KeyCombo.controlMask | KeyCombo.optionMask)
        let restored = try #require(KeyCombo(storageString: combo.storageString))
        #expect(restored == combo)
        #expect(KeyCombo(storageString: "garbage") == nil)
        #expect(KeyCombo(storageString: "17:") == nil)
    }
}

@Suite struct PopupLayoutTests {
    private let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)

    /// The width is a property of the query, fixed for the whole lookup.
    @Test func widthComesFromTheQueryAlone() {
        #expect(PopupLayout.width(forQuery: "bank") == PopupLayout.narrowWidth)
        #expect(PopupLayout.width(forQuery: "look up to") == PopupLayout.narrowWidth)
        #expect(PopupLayout.width(forQuery: "") == PopupLayout.narrowWidth)
        #expect(PopupLayout.width(forQuery: "look up to them") == PopupLayout.wideWidth)
        let sentence = "The committee postponed its decision until the auditors had reviewed every account."
        #expect(PopupLayout.width(forQuery: sentence) == PopupLayout.wideWidth)
    }

    @Test func aVeryLongWordGetsTheWidePanel() {
        #expect(PopupLayout.width(forQuery: "pneumonoultramicroscopicsilicovolcanoconiosis") == PopupLayout.wideWidth)
    }

    @Test func moreThanThreeWordsIsASentence() {
        #expect(!PopupLayout.isSentence("serendipity"))
        #expect(!PopupLayout.isSentence("  look   up  to "))
        #expect(PopupLayout.isSentence("once upon a time"))
    }

    @Test func topLeftCornerSitsAtThePointer() {
        let frame = PopupLayout.frame(
            for: CGSize(width: 380, height: 300),
            pointer: CGPoint(x: 600, y: 700),
            visible: screen
        )
        #expect(frame.minX == 600)
        #expect(frame.maxY == 700)
    }

    @Test func panelIsClampedIntoTheVisibleFrame() {
        let nearRight = PopupLayout.frame(
            for: CGSize(width: 440, height: 300),
            pointer: CGPoint(x: 1430, y: 700),
            visible: screen
        )
        #expect(nearRight.maxX == screen.maxX)
        let nearBottom = PopupLayout.frame(
            for: CGSize(width: 380, height: 400),
            pointer: CGPoint(x: 400, y: 120),
            visible: screen
        )
        #expect(nearBottom.minY == screen.minY)
        #expect(nearBottom.height == 400)
    }

    @Test func panelStaysOnASecondScreenWithANegativeOrigin() {
        let left = CGRect(x: -1920, y: 0, width: 1920, height: 1080)
        let frame = PopupLayout.frame(for: CGSize(width: 380, height: 200), pointer: CGPoint(x: -10, y: 500), visible: left)
        #expect(frame.maxX <= left.maxX)
        #expect(left.contains(frame))
    }

    @Test func growingKeepsTheTopEdge() {
        let original = CGRect(x: 300, y: 500, width: 380, height: 200)
        let grown = PopupLayout.resized(original, toHeight: 320, visible: screen)
        #expect(grown.maxY == original.maxY)
        #expect(grown.minX == original.minX)
        #expect(grown.width == original.width)
        #expect(grown.height == 320)
    }

    /// Growth that would cross the bottom moves the panel up just enough.
    @Test func growthAtTheBottomMovesThePanelUp() {
        let original = CGRect(x: 300, y: 40, width: 380, height: 120)
        let grown = PopupLayout.resized(original, toHeight: 400, visible: screen)
        #expect(grown.minY == screen.minY)
        #expect(grown.height == 400)
    }
}

@Suite struct PopupHeightTests {
    @Test func capIsTwoThirdsOfTheScreenUpToAFixedCeiling() {
        #expect(abs(PopupLayout.heightCap(forVisibleHeight: 600) - 396) < 0.001)
        #expect(abs(PopupLayout.heightCap(forVisibleHeight: 875) - 577.5) < 0.001)
        #expect(PopupLayout.heightCap(forVisibleHeight: 1400) == PopupLayout.maxHeight)
    }

    @Test func heightFollowsTheContentUnderTheCap() {
        #expect(PopupLayout.height(forNatural: 212.3, visibleHeight: 900) == 213)
        #expect(PopupLayout.height(forNatural: 5000, visibleHeight: 900) == PopupLayout.heightCap(forVisibleHeight: 900))
        #expect(PopupLayout.height(forNatural: 0, visibleHeight: 900) == PopupLayout.minHeight)
    }

    @Test func capNeverCollapses() {
        #expect(PopupLayout.heightCap(forVisibleHeight: 0) == PopupLayout.minHeight)
    }
}

@Suite struct PopupContentTests {
    @Test func aTranslationIsAResult() {
        #expect(PopupContent.hasResult(ViewState(original: "bank", translationRaw: "банк")))
    }

    /// Unknown text comes back unchanged; that is not a translation.
    @Test func anEchoedQueryIsNoResult() {
        #expect(!PopupContent.hasResult(ViewState(original: "qwzxv", translationRaw: "qwzxv")))
        #expect(!PopupContent.hasResult(ViewState(original: "Qwzxv", translationRaw: "qwzxv.")))
        #expect(!PopupContent.hasResult(ViewState(original: "qwzxv", loading: true)))
    }

    @Test func dictionaryContentAloneIsAResult() {
        var state = ViewState(original: "set", translationRaw: "set")
        state.definitionsItems = ["to put something somewhere"]
        #expect(PopupContent.hasResult(state))
    }

    /// A word's alternatives read as one list; two whole sentences do not.
    @Test func sentenceAlternativesBecomeParagraphs() {
        #expect(PopupContent.translationParagraphs("банка; банк; берег") == ["банка; банк; берег"])
        #expect(
            PopupContent.translationParagraphs("Комитет отложил решение.; Комитет отложил своё решение.")
                == ["Комитет отложил решение.", "Комитет отложил своё решение."]
        )
        #expect(PopupContent.translationParagraphs("Он пришёл?; Он пришёл") == ["Он пришёл?", "Он пришёл"])
        #expect(PopupContent.translationParagraphs("") == [])
    }
}

@Suite struct PopupFocusRuleTests {
    /// Esc and outside clicks end the lookup; nothing else does.
    @Test func onlyDismissalEndsTheSession() {
        #expect(PopupHideReason.dismissed.endsSession)
        #expect(!PopupHideReason.ownWindowFocused.endsSession)
        #expect(!PopupHideReason.announcementEnded.endsSession)
        #expect(!PopupHideReason.programmatic.endsSession)
    }

    /// Opening Add to Anki from the panel must not close the session it is reading.
    @Test func ownWindowTakingFocusHidesQuietly() {
        let reason = PopupFocusRule.reasonAfterResigningKey(
            panelStillKey: false, newKeyWindowIsOurs: true, dismissalSuspended: false
        )
        #expect(reason == .ownWindowFocused)
    }

    @Test func focusLeavingTheAppDismisses() {
        let reason = PopupFocusRule.reasonAfterResigningKey(
            panelStillKey: false, newKeyWindowIsOurs: false, dismissalSuspended: false
        )
        #expect(reason == .dismissed)
    }

    @Test func regainedKeyOrSuspendedDoesNothing() {
        #expect(PopupFocusRule.reasonAfterResigningKey(
            panelStillKey: true, newKeyWindowIsOurs: false, dismissalSuspended: false
        ) == nil)
        #expect(PopupFocusRule.reasonAfterResigningKey(
            panelStillKey: false, newKeyWindowIsOurs: false, dismissalSuspended: true
        ) == nil)
    }

    /// A clicked announcement is key; losing key again ends no session, wherever focus went.
    @Test func announcementLosingKeyEndsNoSession() {
        for ours in [false, true] {
            let reason = PopupFocusRule.reasonAfterResigningKey(
                panelStillKey: false, newKeyWindowIsOurs: ours, dismissalSuspended: false,
                showingAnnouncement: true
            )
            #expect(reason == .announcementEnded)
            #expect(reason?.endsSession == false)
        }
        #expect(PopupFocusRule.reasonAfterResigningKey(
            panelStillKey: true, newKeyWindowIsOurs: false, dismissalSuspended: false,
            showingAnnouncement: true
        ) == nil)
    }

    /// Esc over one of our windows belongs to that window while an announcement that never
    /// took key is up; a lookup, or an announcement the user clicked, takes it.
    @Test func escapeGoesToTheAnnouncementOnlyWhenKey() {
        #expect(!PopupFocusRule.takesEscape(panelIsKey: false, showingAnnouncement: true))
        #expect(PopupFocusRule.takesEscape(panelIsKey: true, showingAnnouncement: true))
        #expect(PopupFocusRule.takesEscape(panelIsKey: false, showingAnnouncement: false))
        #expect(PopupFocusRule.takesEscape(panelIsKey: true, showingAnnouncement: false))
    }
}

@Suite struct PopupExamplesRowTests {
    @Test func newOnlyWhenThereAreExamplesToReplace() {
        #expect(PopupFooterRow.examplesTitle(canRefresh: true, isSentence: false, hasExamples: true) == "New Examples")
        #expect(PopupFooterRow.examplesTitle(canRefresh: true, isSentence: false, hasExamples: false) == "Find Examples")
    }

    @Test func noRowForSentencesOrWhenTheBackendCannot() {
        #expect(PopupFooterRow.examplesTitle(canRefresh: true, isSentence: true, hasExamples: false) == nil)
        #expect(PopupFooterRow.examplesTitle(canRefresh: false, isSentence: false, hasExamples: true) == nil)
    }
}

@Suite struct ErrorWordingTests {
    @Test func aMissingBackendReadsTheSameWhateverTheClientSaid() {
        let sentences = [
            ErrorWording.sentence(code: "disconnected", message: "Backend is not connected."),
            ErrorWording.sentence(code: "disconnected", message: "Backend connection closed."),
            ErrorWording.sentence(code: "write_failed", message: "Failed to write to backend."),
        ]
        #expect(Set(sentences) == [ErrorWording.backendNotRunning])
        #expect(ErrorWording.backendNotRunning == "Translator’s backend isn’t running.")
    }

    @Test func internalIdsNeverReachTheUser() {
        let gone = ErrorWording.sentence(code: "no_active_entry", message: "No history entry -1.")
        #expect(gone == "This entry is no longer in History.")
        #expect(!gone.contains("-1"))
        #expect(!ErrorWording.sentence(code: "timeout", message: "translate timed out.").contains("translate"))
        #expect(!ErrorWording.sentence(code: "invalid_params", message: "'text' must be a string").contains("'text'"))
    }

    @Test func ankisOwnWordsAreKept() {
        #expect(ErrorWording.sentence(code: "anki_error", message: "deck was not found") == "deck was not found")
        #expect(ErrorWording.sentence(code: "anki_error", message: "") == "Anki didn’t answer.")
    }

    /// Typographic apostrophes, contractions, and a full stop, like every other string.
    @Test func everySentenceIsWrittenInTheAppsVoice() {
        let codes = ["disconnected", "write_failed", "timeout", "no_active_entry", "not_ready",
                     "unknown_method", "bad_request", "invalid_params", "internal", "anything"]
        for code in codes {
            let sentence = ErrorWording.sentence(code: code, message: "")
            #expect(!sentence.contains("'"), "\(code): \(sentence)")
            #expect(!sentence.contains("Could not") && !sentence.contains("not connected"), "\(code): \(sentence)")
            #expect(sentence.hasSuffix("."), "\(code): \(sentence)")
        }
    }
}

@Suite struct PopupFooterNavigationTests {
    private let all: PopupFooterNavigation.Rows = [
        (.addToAnki, true), (.copyTranslation, true), (.newExamples, true),
    ]
    /// Anki not running: its row is disabled and the keyboard steps over it.
    private let noAnki: PopupFooterNavigation.Rows = [
        (.addToAnki, false), (.copyTranslation, true), (.newExamples, true),
    ]

    @Test func downStartsAtTheFirstEnabledRowAndUpAtTheLast() {
        #expect(PopupFooterNavigation.move(from: nil, step: 1, rows: all) == .addToAnki)
        #expect(PopupFooterNavigation.move(from: nil, step: -1, rows: all) == .newExamples)
        #expect(PopupFooterNavigation.move(from: nil, step: 1, rows: noAnki) == .copyTranslation)
    }

    @Test func arrowsSkipDisabledRowsAndStopAtTheEnds() {
        #expect(PopupFooterNavigation.move(from: .copyTranslation, step: 1, rows: noAnki) == .newExamples)
        #expect(PopupFooterNavigation.move(from: .newExamples, step: 1, rows: noAnki) == .newExamples)
        #expect(PopupFooterNavigation.move(from: .copyTranslation, step: -1, rows: noAnki) == .copyTranslation)
        #expect(PopupFooterNavigation.move(from: .newExamples, step: -1, rows: all) == .copyTranslation)
    }

    @Test func noEnabledRowsMeansNoHighlight() {
        let none: PopupFooterNavigation.Rows = [(.addToAnki, false), (.copyTranslation, false)]
        #expect(PopupFooterNavigation.move(from: nil, step: 1, rows: none) == nil)
        #expect(PopupFooterNavigation.move(from: nil, step: 1, rows: []) == nil)
    }

    /// Return activates the highlighted row, and Add to Anki… when nothing is highlighted.
    @Test func returnActivatesTheHighlightOrTheDefaultRow() {
        #expect(PopupFooterNavigation.activation(highlighted: .newExamples, rows: all) == .newExamples)
        #expect(PopupFooterNavigation.activation(highlighted: nil, rows: all) == .addToAnki)
        #expect(PopupFooterNavigation.activation(highlighted: nil, rows: noAnki) == nil)
        #expect(PopupFooterNavigation.activation(highlighted: .addToAnki, rows: noAnki) == nil)
    }
}

@Suite struct PopupSpeechTests {
    @Test func shortcutsAreSpokenAsWords() {
        #expect(KeyGlyphs.spoken(modifiers: "⇧⌘", key: "C") == "Shift-Command-C")
        #expect(KeyGlyphs.spoken(modifiers: "⌘", key: "R") == "Command-R")
        #expect(KeyGlyphs.spoken(modifiers: "", key: "↩") == "Return")
    }

    @Test func aWordIsSpokenWithItsFirstTranslation() {
        let state = ViewState(original: "bank", translation: "банк; берег")
        #expect(PopupSpeech.summary(for: state, error: nil) == "bank: банк; берег")
    }

    @Test func aDictionaryOnlyResultSpeaksItsFirstSense() {
        let apple = AppleLexical(entries: [
            AppleEntry(pos: "noun", senses: [AppleSense(index: 1, label: "luck", translation: "")]),
            AppleEntry(pos: "verb", senses: [AppleSense(index: 1, translation: "ставить")]),
        ])
        let state = ViewState(original: "set", apple: apple)
        #expect(PopupSpeech.summary(for: state, error: nil) == "set: ставить")
    }

    @Test func aSentenceIsSpokenAsItsTranslation() {
        let state = ViewState(
            original: "The committee postponed its decision.",
            translation: "Комитет отложил решение.; Комитет отложил своё решение."
        )
        #expect(PopupSpeech.summary(for: state, error: nil) == "Комитет отложил решение.")
    }

    @Test func nothingFoundOrAFailureIsSaidSo() {
        let empty = ViewState(original: "qwzxv", translation: "qwzxv")
        #expect(PopupSpeech.summary(for: empty, error: nil) == "No translation for “qwzxv”.")
        #expect(PopupSpeech.summary(for: empty, error: "Backend is not connected.") == "Backend is not connected.")
    }
}

@Suite struct ReconnectPolicyTests {
    /// The burst has to stay short so an already-running backend appears instantly.
    @Test func firstRoundStartsImmediately() {
        let policy = ReconnectPolicy()
        #expect(policy.delayBeforeRound(1) == 0)
        #expect(policy.burstAttempts == 40)
        #expect(policy.burstDelay == 0.1)
    }

    /// This backend needs 6 to 14 seconds to start, so later rounds back off but keep
    /// coming: a restarting daemon is picked up within a second of listening.
    @Test func laterRoundsBackOffAndAreCapped() {
        let policy = ReconnectPolicy()
        #expect(policy.delayBeforeRound(2) == 1.0)
        #expect(policy.delayBeforeRound(3) == 2.0)
        #expect(policy.delayBeforeRound(4) == 4.0)
        #expect(policy.delayBeforeRound(5) == 5.0)
        #expect(policy.delayBeforeRound(50) == 5.0)
    }

    @Test func degenerateValuesAreClamped() {
        let policy = ReconnectPolicy(burstAttempts: 0, burstDelay: -1, idleDelay: -1, maxIdleDelay: -1)
        #expect(policy.burstAttempts == 1)
        #expect(policy.burstDelay == 0)
        #expect(policy.idleDelay == 0)
        #expect(policy.maxIdleDelay == 0)
        #expect(policy.delayBeforeRound(3) == 0)
    }

    @Test func waitingMessageReadsAsStillTrying() {
        let message = ReconnectPolicy().waitingMessage(socketPath: "/tmp/x.sock")
        #expect(message.contains("Waiting"))
        #expect(message.contains("/tmp/x.sock"))
    }
}
