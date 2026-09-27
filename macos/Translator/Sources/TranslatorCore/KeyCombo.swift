import Foundation

/// A global keyboard shortcut in Carbon terms (virtual key code + Carbon modifier mask).
public struct KeyCombo: Codable, Equatable, Hashable, Sendable {
    public static let commandMask: UInt32 = 0x0100
    public static let shiftMask: UInt32 = 0x0200
    public static let optionMask: UInt32 = 0x0800
    public static let controlMask: UInt32 = 0x1000

    /// ⌥⌘T
    public static let defaultCombo = KeyCombo(keyCode: 17, modifiers: commandMask | optionMask)

    public var keyCode: UInt32
    public var modifiers: UInt32

    public init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers & (Self.commandMask | Self.shiftMask | Self.optionMask | Self.controlMask)
    }

    /// Something a global hot key can sensibly be: at least one non-shift modifier.
    public var isUsable: Bool {
        modifiers & (Self.commandMask | Self.optionMask | Self.controlMask) != 0
    }

    /// "⌃⌥⇧⌘T" — macOS canonical modifier order.
    public var displayString: String {
        var text = ""
        if modifiers & Self.controlMask != 0 { text += "⌃" }
        if modifiers & Self.optionMask != 0 { text += "⌥" }
        if modifiers & Self.shiftMask != 0 { text += "⇧" }
        if modifiers & Self.commandMask != 0 { text += "⌘" }
        return text + Self.keyName(for: keyCode)
    }

    // MARK: Persistence ("keyCode:modifiers")

    public var storageString: String { "\(keyCode):\(modifiers)" }

    public init?(storageString: String) {
        let parts = storageString.split(separator: ":")
        guard parts.count == 2, let key = UInt32(parts[0]), let mods = UInt32(parts[1]) else { return nil }
        self.init(keyCode: key, modifiers: mods)
    }

    // MARK: Key names (US ANSI virtual key codes)

    private static let names: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2",
        20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8",
        29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "↩", 37: "L",
        38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M",
        47: ".", 48: "⇥", 49: "Space", 50: "`", 51: "⌫", 53: "⎋", 96: "F5", 97: "F6",
        98: "F7", 99: "F3", 100: "F8", 101: "F9", 103: "F11", 105: "F13", 107: "F14",
        109: "F10", 111: "F12", 113: "F15", 115: "↖", 116: "⇞", 117: "⌦", 118: "F4",
        119: "↘", 120: "F2", 121: "⇟", 122: "F1", 123: "←", 124: "→", 125: "↓", 126: "↑",
    ]

    public static func keyName(for keyCode: UInt32) -> String {
        names[keyCode] ?? "Key \(keyCode)"
    }
}

// MARK: - Combinations something else already answers to

/// A menu item's key equivalent, in the terms AppKit gives it: the character and the
/// modifiers. An upper-case letter carries an implied ⇧, as it does in `NSMenuItem`.
public struct MenuKeyEquivalent: Equatable, Sendable {
    public var title: String
    public var key: String
    /// Carbon mask, as `KeyCombo.modifiers`.
    public var modifiers: UInt32

    public init(title: String, key: String, modifiers: UInt32) {
        self.title = title
        var modifiers = modifiers
        if key.count == 1, key.lowercased() != key {
            modifiers |= KeyCombo.shiftMask
        }
        self.key = key.lowercased()
        self.modifiers = modifiers & KeyCombo.allModifiers
    }
}

/// A system-wide shortcut from `CopySymbolicHotKeys` (Mission Control, Spotlight, input
/// sources…): a virtual key code and a Carbon modifier mask.
public struct SystemHotKey: Equatable, Sendable {
    public var keyCode: UInt32
    public var modifiers: UInt32
    public var enabled: Bool

    public init(keyCode: UInt32, modifiers: UInt32, enabled: Bool) {
        self.keyCode = keyCode
        self.modifiers = modifiers & KeyCombo.allModifiers
        self.enabled = enabled
    }
}

/// Why a combination cannot be the global shortcut. A Carbon hot key takes its
/// combination from every app, so one that a menu or the system already uses would stop
/// working there: ⌘C would no longer copy anywhere.
public enum ShortcutConflict: Equatable, Sendable {
    /// A menu item of this app answers to it (Edit > Copy, Quit…).
    case menuItem(String)
    /// macOS answers to it (System Settings > Keyboard > Keyboard Shortcuts).
    case systemShortcut
    /// ⌘ with one letter or digit and nothing else: what every app uses for its own
    /// commands, even where this app's menu does not.
    case appCommand
    /// ⌥ or ⌥⇧ with a character key: it types a character (⌥E is the accent key, and the
    /// ⌥ layer of many layouts holds letters), and since macOS 15 the system no longer
    /// delivers such a combination to a global shortcut — as KeyboardShortcuts' own
    /// `isDisallowed` says.
    case typesCharacter

    /// The alert's title.
    public func message(for combo: KeyCombo) -> String {
        switch self {
        case let .menuItem(title):
            return "\(combo.displayString) is already used by the menu item “\(title)”."
        case .systemShortcut:
            return "\(combo.displayString) is already used by macOS."
        case .appCommand:
            return "\(combo.displayString) is used by apps for their own commands."
        case .typesCharacter:
            return "\(combo.displayString) types a character, so it can’t be a shortcut."
        }
    }

    /// The alert's advice.
    public var advice: String {
        switch self {
        case .menuItem, .appCommand:
            return "A global shortcut would take it away from every app. Choose one with ⌥ or ⌃, such as ⌥⌘T."
        case .systemShortcut:
            return "It is set in System Settings > Keyboard > Keyboard Shortcuts. Choose another combination, or turn that one off there."
        case .typesCharacter:
            return "macOS doesn’t support shortcuts made of only ⌥ or ⌥⇧ and a key that types. Add ⌘ or ⌃, such as ⌥⌘T."
        }
    }
}

extension KeyCombo {
    static let allModifiers = commandMask | shiftMask | optionMask | controlMask

    /// The character a menu item would show for this key, when it has one.
    public var menuCharacter: String? {
        let name = Self.keyName(for: keyCode)
        if name == "Space" { return " " }
        guard name.count == 1, let scalar = name.unicodeScalars.first, scalar.isASCII else { return nil }
        return name.lowercased()
    }

    /// The first thing that already answers to this combination, or nil when it is free.
    ///
    /// `menuItems` holds every command of this app with a key equivalent: its main menu
    /// and the popup's own commands (⇧⌘C, ⌘R), which no menu lists. A hot key on one of
    /// those would fire instead of the command whenever the popup is key.
    public func conflict(menuItems: [MenuKeyEquivalent], systemHotKeys: [SystemHotKey]) -> ShortcutConflict? {
        if menuCharacter != nil,
           modifiers == Self.optionMask || modifiers == Self.optionMask | Self.shiftMask {
            return .typesCharacter
        }
        if let character = menuCharacter,
           let item = menuItems.first(where: { $0.key == character && $0.modifiers == modifiers }) {
            return .menuItem(item.title)
        }
        if systemHotKeys.contains(where: { $0.enabled && $0.keyCode == keyCode && $0.modifiers == modifiers }) {
            return .systemShortcut
        }
        if modifiers == Self.commandMask, let character = menuCharacter,
           let scalar = character.unicodeScalars.first,
           CharacterSet.alphanumerics.contains(scalar) {
            return .appCommand
        }
        return nil
    }
}
