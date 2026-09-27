import Testing
@testable import TranslatorCore

/// The recorder refuses a combination that something else already answers to, because a
/// Carbon hot key would take it away from every app.
@Suite struct ShortcutConflictTests {
    private let c: UInt32 = 8
    private let w: UInt32 = 13
    private let t: UInt32 = 17
    private let comma: UInt32 = 43
    private let space: UInt32 = 49

    /// What SwiftUI's menu for this app holds, plus the File > Close the app adds.
    private var menu: [MenuKeyEquivalent] {
        [
            MenuKeyEquivalent(title: "Copy", key: "c", modifiers: KeyCombo.commandMask),
            MenuKeyEquivalent(title: "Redo", key: "Z", modifiers: KeyCombo.commandMask),
            MenuKeyEquivalent(title: "Settings…", key: ",", modifiers: KeyCombo.commandMask),
            MenuKeyEquivalent(title: "Close", key: "w", modifiers: KeyCombo.commandMask),
        ]
    }

    @Test func aMenuItemsKeyIsTakenAndNamed() {
        let copy = KeyCombo(keyCode: c, modifiers: KeyCombo.commandMask)
        #expect(copy.conflict(menuItems: menu, systemHotKeys: []) == .menuItem("Copy"))
        let settings = KeyCombo(keyCode: comma, modifiers: KeyCombo.commandMask)
        #expect(settings.conflict(menuItems: menu, systemHotKeys: []) == .menuItem("Settings…"))
    }

    @Test func anUpperCaseKeyEquivalentMeansShift() {
        let redo = KeyCombo(keyCode: 6, modifiers: KeyCombo.commandMask | KeyCombo.shiftMask)
        #expect(redo.conflict(menuItems: menu, systemHotKeys: []) == .menuItem("Redo"))
        // ⌘Z without ⇧ is not Redo; it is still an app command (Undo) by the ⌘-letter rule.
        let undo = KeyCombo(keyCode: 6, modifiers: KeyCombo.commandMask)
        #expect(undo.conflict(menuItems: menu, systemHotKeys: []) == .appCommand)
    }

    @Test func modifiersMustMatchExactly() {
        let optionCopy = KeyCombo(keyCode: c, modifiers: KeyCombo.commandMask | KeyCombo.optionMask)
        #expect(optionCopy.conflict(menuItems: menu, systemHotKeys: []) == nil)
    }

    @Test func anEnabledSystemShortcutIsTaken() {
        let spotlight = KeyCombo(keyCode: space, modifiers: KeyCombo.commandMask)
        let system = [SystemHotKey(keyCode: space, modifiers: KeyCombo.commandMask, enabled: true)]
        #expect(spotlight.conflict(menuItems: [], systemHotKeys: system) == .systemShortcut)
        let off = [SystemHotKey(keyCode: space, modifiers: KeyCombo.commandMask, enabled: false)]
        #expect(spotlight.conflict(menuItems: [], systemHotKeys: off) == nil)
    }

    @Test func systemModifierBitsBeyondTheFourAreIgnored() {
        // CopySymbolicHotKeys may carry extra bits (the function-key flag) in its mask.
        let hotKey = SystemHotKey(keyCode: 123, modifiers: KeyCombo.controlMask | 0x800000, enabled: true)
        let combo = KeyCombo(keyCode: 123, modifiers: KeyCombo.controlMask)
        #expect(combo.conflict(menuItems: [], systemHotKeys: [hotKey]) == .systemShortcut)
    }

    @Test func commandAndOneLetterOrDigitIsAnAppCommand() {
        let close = KeyCombo(keyCode: w, modifiers: KeyCombo.commandMask)
        #expect(close.conflict(menuItems: [], systemHotKeys: []) == .appCommand)
        let digit = KeyCombo(keyCode: 18, modifiers: KeyCombo.commandMask)
        #expect(digit.conflict(menuItems: [], systemHotKeys: []) == .appCommand)
    }

    @Test func theDefaultAndOtherModifierRichCombinationsAreFree() {
        #expect(KeyCombo.defaultCombo.conflict(menuItems: menu, systemHotKeys: []) == nil)
        let controlOptionK = KeyCombo(keyCode: 40, modifiers: KeyCombo.controlMask | KeyCombo.optionMask)
        #expect(controlOptionK.conflict(menuItems: menu, systemHotKeys: []) == nil)
        let commandF5 = KeyCombo(keyCode: 96, modifiers: KeyCombo.commandMask)
        #expect(commandF5.conflict(menuItems: menu, systemHotKeys: []) == nil)
    }

    @Test func theMenuWinsOverTheGenericRuleSoTheAlertCanNameIt() {
        let close = KeyCombo(keyCode: w, modifiers: KeyCombo.commandMask)
        #expect(close.conflict(menuItems: menu, systemHotKeys: []) == .menuItem("Close"))
        #expect(ShortcutConflict.menuItem("Close").message(for: close) == "⌘W is already used by the menu item “Close”.")
    }

    @Test func menuCharacterCoversPrintableKeysOnly() {
        #expect(KeyCombo(keyCode: t, modifiers: 0).menuCharacter == "t")
        #expect(KeyCombo(keyCode: space, modifiers: 0).menuCharacter == " ")
        #expect(KeyCombo(keyCode: 123, modifiers: 0).menuCharacter == nil)
        #expect(KeyCombo(keyCode: 96, modifiers: 0).menuCharacter == nil)
    }
}

/// Settings typed while the backend is away must neither be lost silently nor be put
/// back by the next load.
@Suite struct SettingsSyncTests {
    @Test func nothingIsSavedBeforeTheFirstLoad() {
        let sync = SettingsSync<Int>()
        #expect(!sync.isLoaded)
        #expect(!sync.needsSave(1))
    }

    @Test func aLoadIsAdoptedWhenNothingIsPending() {
        var sync = SettingsSync<Int>()
        #expect(sync.loaded(5, local: 0, saveInProgress: false) == .adopt)
        #expect(sync.isLoaded)
        #expect(sync.needsSave(6))
        #expect(!sync.needsSave(5))
    }

    @Test func aPendingSaveKeepsTheLocalValues() {
        var sync = SettingsSync<Int>()
        _ = sync.loaded(5, local: 0, saveInProgress: false)
        #expect(sync.loaded(5, local: 6, saveInProgress: true) == .keepLocal)
        #expect(sync.synced == 5)
    }

    @Test func aFailedSaveIsSentAgainInsteadOfReverted() {
        var sync = SettingsSync<Int>()
        _ = sync.loaded(5, local: 0, saveInProgress: false)
        sync.saveDidFail()
        // The window becomes key again, or the backend reconnects: the load brings 5.
        #expect(sync.loaded(5, local: 6, saveInProgress: false) == .retrySave)
        #expect(sync.synced == 5)
        #expect(sync.saveFailed)
        sync.saved(6)
        #expect(!sync.saveFailed)
        #expect(sync.loaded(6, local: 6, saveInProgress: false) == .adopt)
    }

    @Test func aFailureUndoneByTheUserIsForgottenOnTheNextLoad() {
        var sync = SettingsSync<Int>()
        _ = sync.loaded(5, local: 0, saveInProgress: false)
        sync.saveDidFail()
        #expect(sync.loaded(7, local: 5, saveInProgress: false) == .adopt)
        #expect(!sync.saveFailed)
        #expect(sync.synced == 7)
    }
}
