import CoreGraphics
import Foundation

/// Geometry for the translation panel.
///
/// The panel follows Maccy's floating panel: its top-left corner sits at the pointer,
/// clamped into the visible frame of that screen; its width is decided once per lookup
/// from the query alone; its height is whatever the content needs, up to a cap, with the
/// top edge fixed while it grows.
public enum PopupLayout {
    /// A word or a short phrase.
    public static let narrowWidth: CGFloat = 380
    /// A sentence, or a word too long for the narrow panel.
    public static let wideWidth: CGFloat = 440
    /// Width of the panel that only says something (no lookup behind it).
    public static let announcementWidth: CGFloat = 320

    /// Up to this many words the query is shown as a headword; beyond it, as a sentence.
    public static let headwordMaxWords = 3
    public static let narrowMaxCharacters = 32

    /// Absolute ceiling on the panel height, and the share of the screen it may take.
    public static let maxHeight: CGFloat = 620
    public static let maxScreenShare: CGFloat = 0.66
    /// Never shorter than one line of banner or header.
    public static let minHeight: CGFloat = 36

    public static func wordCount(_ query: String) -> Int {
        query.split(whereSeparator: { $0.isWhitespace }).count
    }

    /// More than a few words: shown as a quoted sentence with the translation as the main text.
    public static func isSentence(_ query: String) -> Bool {
        wordCount(query.trimmingCharacters(in: .whitespacesAndNewlines)) > headwordMaxWords
    }

    /// Decided at show time from the query and kept for the whole lookup, so the panel
    /// never jumps sideways while the result fills in.
    public static func width(forQuery query: String) -> CGFloat {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return narrowWidth }
        if wordCount(trimmed) <= headwordMaxWords && trimmed.count <= narrowMaxCharacters {
            return narrowWidth
        }
        return wideWidth
    }

    /// The tallest the panel may be on a screen whose visible frame is `visibleHeight` tall.
    public static func heightCap(forVisibleHeight visibleHeight: CGFloat) -> CGFloat {
        max(minHeight, min(visibleHeight * maxScreenShare, maxHeight))
    }

    /// The content's natural height, capped; the body scrolls inside when capped.
    public static func height(forNatural natural: CGFloat, visibleHeight: CGFloat) -> CGFloat {
        let rounded = natural.rounded(.up)
        return min(max(rounded, minHeight), heightCap(forVisibleHeight: visibleHeight))
    }

    /// Top-left corner at the pointer (AppKit coordinates, origin bottom-left), the whole
    /// panel kept inside `visible` so it never spills onto a neighbouring screen.
    public static func frame(for size: CGSize, pointer: CGPoint, visible: CGRect) -> CGRect {
        let origin = CGPoint(x: pointer.x, y: pointer.y - size.height)
        return CGRect(origin: constrained(origin, size: size, to: visible), size: size)
    }

    /// A new height with the top edge fixed. When growing would cross the bottom of the
    /// visible frame the panel moves up just enough; it never leaves the screen at the top.
    public static func resized(_ frame: CGRect, toHeight height: CGFloat, visible: CGRect) -> CGRect {
        let size = CGSize(width: frame.width, height: height)
        let origin = CGPoint(x: frame.minX, y: frame.maxY - height)
        return CGRect(origin: constrained(origin, size: size, to: visible), size: size)
    }

    private static func constrained(_ origin: CGPoint, size: CGSize, to visible: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(origin.x, visible.minX), max(visible.minX, visible.maxX - size.width)),
            y: min(max(origin.y, visible.minY), max(visible.minY, visible.maxY - size.height))
        )
    }
}

/// Why the translation panel went away, and whether that ends the lookup.
///
/// Only the user dismissing the panel ends the backend session. Hiding it because one of
/// the app's own windows took focus must not: closing the session cancels pending Anki
/// work and clears the preview the Add to Anki window is still preparing.
public enum PopupHideReason: String, Equatable, Sendable {
    /// Esc, or a click into another app or the desktop.
    case dismissed
    /// Another window of this app became key (Add to Anki, History, Settings).
    case ownWindowFocused
    /// A short announcement ran its course.
    case announcementEnded
    /// Replaced or hidden by the app itself (a new lookup, the snapshot harness).
    case programmatic

    public var endsSession: Bool { self == .dismissed }
}

public enum PopupFocusRule {
    /// What losing key status means, decided once focus has settled.
    ///
    /// - Parameters:
    ///   - panelStillKey: the panel got key back (e.g. a click inside it).
    ///   - newKeyWindowIsOurs: another window of this app is key now.
    ///   - dismissalSuspended: a capture run that must not react to focus theft.
    public static func reasonAfterResigningKey(
        panelStillKey: Bool,
        newKeyWindowIsOurs: Bool,
        dismissalSuspended: Bool
    ) -> PopupHideReason? {
        if panelStillKey || dismissalSuspended { return nil }
        return newKeyWindowIsOurs ? .ownWindowFocused : .dismissed
    }
}

/// What the panel has to show for a state.
public enum PopupContent {
    /// Whether the lookup produced anything worth reading.
    ///
    /// An engine that knows nothing about the text echoes it back as the "translation";
    /// that is no result, and the panel says so instead of repeating the query.
    public static func hasResult(_ state: ViewState) -> Bool {
        let hasEntries = !(state.apple?.groupedEntries.isEmpty ?? true)
        if hasEntries || !state.definitionsItems.isEmpty || !state.examples.isEmpty { return true }
        guard state.hasTranslation else { return false }
        return normalized(state.translationText) != normalized(state.originalText)
    }

    private static func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)).lowercased()
    }
}
