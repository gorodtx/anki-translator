import AppKit
import Carbon.HIToolbox
import SwiftUI
import TranslatorCore

/// Global hot key via Carbon `RegisterEventHotKey` — works with no TCC permission at all.
///
/// Carbon is the only API that still delivers a system-wide shortcut without Accessibility
/// or Input Monitoring, which is why AppKit-era code keeps using it.
@MainActor
final class HotKeyManager {
    private var handlerRef: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private var combo: KeyCombo?
    private var action: (() -> Void)?
    private let signature = OSType(0x54524E53) // 'TRNS'

    /// Registers `combo`; replaces any previous registration. Returns false when the
    /// shortcut is already taken by another app.
    @discardableResult
    func register(_ combo: KeyCombo, action: @escaping () -> Void) -> Bool {
        unregister()
        self.combo = combo
        self.action = action
        installHandlerIfNeeded()

        var reference: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: signature, id: 1)
        let status = RegisterEventHotKey(
            combo.keyCode,
            combo.modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &reference
        )
        guard status == noErr, let reference else {
            self.combo = nil
            return false
        }
        hotKeyRef = reference
        return true
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        combo = nil
    }

    var current: KeyCombo? { combo }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, userData in
                guard let userData, let event else { return OSStatus(eventNotHandledErr) }
                var pressedID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &pressedID
                )
                guard status == noErr else { return status }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                MainActor.assumeIsolated { manager.action?() }
                return noErr
            },
            1,
            &spec,
            context,
            &handlerRef
        )
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}

/// What already answers to a combination on this Mac: this app's own menus (Edit > Copy,
/// File > Close, Quit…) and the system's shortcuts. The matching itself is
/// `KeyCombo.conflict`, under test; this only reads the two lists.
@MainActor
enum ShortcutAvailability {
    static func conflict(for combo: KeyCombo) -> ShortcutConflict? {
        combo.conflict(
            menuItems: menuItems(in: NSApp.mainMenu) + popupCommands,
            systemHotKeys: systemHotKeys()
        )
    }

    /// The popup's own commands, which no menu lists: taken by the hot key, ⇧⌘C in a key
    /// popup would close it (a second press closes it) instead of copying. Read from the
    /// footer rows themselves so the two cannot drift apart; a bare key (Return) is left
    /// out, since a hot key always has a modifier.
    static var popupCommands: [MenuKeyEquivalent] {
        PopupFooterRow.allCases.compactMap { row in
            let shortcut = row.keyboardShortcut
            guard !shortcut.modifiers.isEmpty else { return nil }
            var modifiers: UInt32 = 0
            if shortcut.modifiers.contains(.command) { modifiers |= KeyCombo.commandMask }
            if shortcut.modifiers.contains(.option) { modifiers |= KeyCombo.optionMask }
            if shortcut.modifiers.contains(.control) { modifiers |= KeyCombo.controlMask }
            if shortcut.modifiers.contains(.shift) { modifiers |= KeyCombo.shiftMask }
            return MenuKeyEquivalent(title: row.title, key: String(shortcut.key.character), modifiers: modifiers)
        }
    }

    /// Every key equivalent of `menu` and its submenus, as KeyboardShortcuts'
    /// `isTakenByMainMenu` walks them.
    static func menuItems(in menu: NSMenu?) -> [MenuKeyEquivalent] {
        guard let menu else { return [] }
        var found: [MenuKeyEquivalent] = []
        for item in menu.items {
            if let submenu = item.submenu { found += menuItems(in: submenu) }
            guard !item.keyEquivalent.isEmpty else { continue }
            found.append(MenuKeyEquivalent(
                title: item.title,
                key: item.keyEquivalent,
                modifiers: carbonModifiers(item.keyEquivalentModifierMask)
            ))
        }
        return found
    }

    /// The system-wide shortcuts of System Settings > Keyboard > Keyboard Shortcuts.
    static func systemHotKeys() -> [SystemHotKey] {
        var list: Unmanaged<CFArray>?
        guard CopySymbolicHotKeys(&list) == noErr,
              let entries = list?.takeRetainedValue() as? [[String: Any]]
        else { return [] }
        return entries.compactMap { entry in
            guard let code = entry[kHISymbolicHotKeyCode] as? Int,
                  let modifiers = entry[kHISymbolicHotKeyModifiers] as? Int
            else { return nil }
            return SystemHotKey(
                keyCode: UInt32(truncatingIfNeeded: code),
                modifiers: UInt32(truncatingIfNeeded: modifiers),
                enabled: entry[kHISymbolicHotKeyEnabled] as? Bool ?? false
            )
        }
    }

    private static func carbonModifiers(_ flags: NSEvent.ModifierFlags) -> UInt32 {
        var modifiers: UInt32 = 0
        if flags.contains(.command) { modifiers |= KeyCombo.commandMask }
        if flags.contains(.option) { modifiers |= KeyCombo.optionMask }
        if flags.contains(.control) { modifiers |= KeyCombo.controlMask }
        if flags.contains(.shift) { modifiers |= KeyCombo.shiftMask }
        return modifiers
    }
}

/// Translates an `NSEvent` key-down into a `KeyCombo` for the shortcut recorder.
enum KeyComboRecorder {
    static func combo(from event: NSEvent) -> KeyCombo? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var modifiers: UInt32 = 0
        if flags.contains(.command) { modifiers |= KeyCombo.commandMask }
        if flags.contains(.option) { modifiers |= KeyCombo.optionMask }
        if flags.contains(.control) { modifiers |= KeyCombo.controlMask }
        if flags.contains(.shift) { modifiers |= KeyCombo.shiftMask }
        let combo = KeyCombo(keyCode: UInt32(event.keyCode), modifiers: modifiers)
        return combo.isUsable ? combo : nil
    }
}
