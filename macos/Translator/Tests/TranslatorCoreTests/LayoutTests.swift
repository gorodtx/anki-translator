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

@Suite struct SurfaceStyleTests {
    @Test func defaultSettingsGetGlass() {
        #expect(SurfaceStyleResolver.panel(reduceTransparency: false, increasedContrast: false) == .glass)
    }

    /// Reduce Transparency means no translucency, so the panel goes opaque.
    @Test func reducedTransparencyGoesOpaque() {
        #expect(
            SurfaceStyleResolver.panel(reduceTransparency: true, increasedContrast: false)
                == .opaque(border: 0.18)
        )
    }

    /// Increase Contrast also goes opaque, with an edge that is actually visible: glass
    /// over arbitrary content cannot promise the contrast that was asked for.
    @Test func increasedContrastGoesOpaqueWithAStrongerEdge() {
        #expect(
            SurfaceStyleResolver.panel(reduceTransparency: false, increasedContrast: true)
                == .opaque(border: 0.45)
        )
        #expect(
            SurfaceStyleResolver.panel(reduceTransparency: true, increasedContrast: true)
                == .opaque(border: 0.45)
        )
    }

    @Test func innerSectionStaysFaintUntilContrastIsAskedFor() {
        let normal = SurfaceStyleResolver.inner(increasedContrast: false)
        #expect(normal.fill == 0.055)
        #expect(normal.border == nil)

        let increased = SurfaceStyleResolver.inner(increasedContrast: true)
        #expect(increased.fill > normal.fill)
        #expect(increased.border == 0.45)
    }
}
