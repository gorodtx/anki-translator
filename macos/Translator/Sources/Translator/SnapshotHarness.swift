import AppKit
import SwiftUI
import TranslatorCore

/// Renders the app's own windows to PNG, so the UI can be looked at without the Screen
/// Recording grant.
///
/// Capturing another app's window needs that grant; capturing one of our own does not.
/// `CGWindowListCreateImage` is obsoleted in the macOS 15 SDK but still answers at runtime
/// for the calling process's windows, composited — real corners, real materials — so it is
/// looked up by name instead of being linked.
@MainActor
enum WindowSnapshot {
    private typealias CaptureFunction = @convention(c) (CGRect, UInt32, UInt32, UInt32) -> Unmanaged<CGImage>?

    private static let capture: CaptureFunction? = {
        guard let symbol = dlsym(dlopen(nil, RTLD_NOW), "CGWindowListCreateImage") else { return nil }
        return unsafeBitCast(symbol, to: CaptureFunction.self)
    }()

    @discardableResult
    static func write(_ window: NSWindow, to url: URL) -> Bool {
        // kCGWindowListOptionIncludingWindow, kCGWindowImageBoundsIgnoreFraming
        guard let capture,
              let image = capture(.null, 1 << 3, UInt32(window.windowNumber), 1 << 0)?.takeRetainedValue(),
              let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
        else {
            NSLog("[snapshot] could not capture window \(window.windowNumber)")
            return false
        }
        do {
            try data.write(to: url)
            NSLog("[snapshot] wrote \(url.lastPathComponent) \(image.width)x\(image.height)")
            return true
        } catch {
            NSLog("[snapshot] write failed: \(error)")
            return false
        }
    }
}

/// Drives the real app through a fixed set of scenes and writes one PNG per scene.
///
/// Started by `TRANSLATOR_DEBUG_SNAPSHOT=<dir>` (see `scripts/snapshot.sh`, which also
/// brings up an isolated backend so real lookups can run without touching the user's
/// history). Nothing here draws anything of its own: every image is the production view
/// in the production window, fed by the production backend.
///
/// - `TRANSLATOR_DEBUG_SNAPSHOT_TEXTS` — lookups to run, separated by `|`.
/// - `TRANSLATOR_DEBUG_APPEARANCE` — `light`, `dark` or `both` (default).
/// - `TRANSLATOR_DEBUG_SNAPSHOT_SCENES` — any of `popup,settings,history,anki` (default all).
/// - `TRANSLATOR_DEBUG_ANKI_TEXT` — the lookup the `anki` scene opens Add to Anki for.
@MainActor
final class SnapshotRunner {
    private weak var delegate: AppDelegate?
    private let output: URL
    private let environment = ProcessInfo.processInfo.environment

    init(delegate: AppDelegate, output: URL) {
        self.delegate = delegate
        self.output = output
    }

    static let defaultTexts = [
        "serendipity",
        "look up",
        "bank",
        "went",
        "The committee postponed its decision until the auditors had reviewed every account.",
        "qwzxv",
    ]

    private var texts: [String] {
        guard let raw = environment["TRANSLATOR_DEBUG_SNAPSHOT_TEXTS"], !raw.isEmpty else {
            return Self.defaultTexts
        }
        return raw.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private var appearances: [(String, NSAppearance.Name)] {
        switch environment["TRANSLATOR_DEBUG_APPEARANCE"] {
        case "light": return [("light", .aqua)]
        case "dark": return [("dark", .darkAqua)]
        default: return [("light", .aqua), ("dark", .darkAqua)]
        }
    }

    private var scenes: Set<String> {
        let raw = environment["TRANSLATOR_DEBUG_SNAPSHOT_SCENES"] ?? "popup,settings,history,anki"
        return Set(raw.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) })
    }

    func run() {
        try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        Task { @MainActor in
            // The backend's retry burst: give the client a moment to connect.
            await waitUntil(timeout: 20) { self.delegate?.model.isConnected == true }
            for (name, appearance) in appearances {
                NSApp.appearance = NSAppearance(named: appearance)
                if scenes.contains("popup") { await popupScenes(appearance: name) }
                if scenes.contains("settings") { await settingsScene(appearance: name) }
                if scenes.contains("history") { await historyScene(appearance: name) }
                if scenes.contains("anki") { await ankiScene(appearance: name) }
            }
            NSLog("[snapshot] done")
            exit(0)
        }
    }

    // MARK: - Scenes

    private func popupScenes(appearance: String) async {
        guard let delegate else { return }
        for (index, text) in texts.enumerated() {
            let slug = Self.slug(text)
            delegate.snapshotPresent(text: text)
            // The first frame, before any answer: what the user sees while waiting.
            if index == 0 {
                try? await Task.sleep(for: .milliseconds(120))
                await capturePopup("popup-\(index)-\(slug)-loading-\(appearance)")
            }
            await waitUntil(timeout: 25) { !delegate.model.state.loading }
            // Resizes run on a 120 ms poll plus an animation; let both finish.
            try? await Task.sleep(for: .milliseconds(900))
            await capturePopup("popup-\(index)-\(slug)-\(appearance)")
        }
        // A banner over a finished card.
        delegate.model.show(banner: "Added to Anki: English::Vocabulary", level: .success)
        try? await Task.sleep(for: .milliseconds(700))
        await capturePopup("popup-banner-\(appearance)")
        delegate.snapshotHidePopup()
        try? await Task.sleep(for: .milliseconds(400))
    }

    private func settingsScene(appearance: String) async {
        guard let delegate else { return }
        delegate.showSettings()
        // The view refreshes ping, settings and Anki on appear.
        try? await Task.sleep(for: .seconds(3))
        guard let window = delegate.snapshotWindow(id: "settings") else { return }
        await captureScrollingPages(window, prefix: "settings-\(appearance)")
        window.close()
        try? await Task.sleep(for: .milliseconds(300))
    }

    /// The list as the popup scenes left it (or its empty state on a fresh backend), then
    /// the no-match state, reached by typing into the toolbar's own search field.
    private func historyScene(appearance: String) async {
        guard let delegate else { return }
        delegate.showHistory()
        try? await Task.sleep(for: .seconds(2))
        guard let window = delegate.snapshotWindow(id: "history") else { return }
        probeReuse("history", window)
        // The frame is autosaved; a size left by an earlier run must not change the image.
        window.setContentSize(HistoryView.defaultSize)
        // Activation is left to the system: forcing it would take the keyboard from
        // whoever is typing on this Mac while the run is on screen. So a window may be
        // captured in its inactive look.
        try? await Task.sleep(for: .milliseconds(300))
        if delegate.model.history.isEmpty {
            write(window, "history-empty-\(appearance)")
        } else {
            write(window, "history-\(appearance)")
            if let table = Self.firstView(ofType: NSTableView.self, in: window.contentView), table.numberOfRows > 1 {
                // The second row selected, the way a click or an arrow key leaves it.
                window.makeFirstResponder(table)
                table.selectRowIndexes([1], byExtendingSelection: false)
                try? await Task.sleep(for: .milliseconds(300))
                write(window, "history-selected-\(appearance)")
                // Return on the selection, then a double-click on another row, must each
                // open that entry in the popup.
                await probeOpens("history-return-opens", expecting: delegate.model.history[1].text) {
                    window.makeKey()
                    window.makeFirstResponder(table)
                    window.sendEvent(Self.key(36, "\r", in: window))
                }
                // Not the newest row: in a default run that is the no-result lookup, and a
                // rich entry followed by an empty one is exactly the resize the old popup
                // crashes on — a popup fault this probe is not about.
                let target = table.numberOfRows > 2 ? 2 : 0
                await probeOpens(
                    "history-double-click-opens",
                    expecting: delegate.model.history[target].text,
                    needsActiveApp: true
                ) {
                    window.makeKey()
                    await Self.doubleClick(row: target, of: table, in: window)
                }
                table.deselectAll(nil)
            }
            if let field = Self.searchField(in: window) {
                // A field that grows on focus has run out of room and pushes the title into
                // the toolbar's overflow menu.
                let idle = field.frame.width
                Self.type("qwzxvq", into: field, of: window)
                try? await Task.sleep(for: .milliseconds(500))
                let verdict = field.frame.width == idle ? "PASS" : "FAIL"
                NSLog("[snapshot] PROBE history-search-width \(verdict) \(idle) -> \(field.frame.width) in \(window.frame.width)")
                write(window, "history-nomatch-\(appearance)")
                Self.type("", into: field, of: window)
                // Leave the keyboard with the list, where the next open expects it.
                window.makeFirstResponder(Self.firstView(ofType: NSTableView.self, in: window.contentView))
                try? await Task.sleep(for: .milliseconds(200))
            } else {
                NSLog("[snapshot] history search field not found in the toolbar")
            }
        }
        window.close()
        try? await Task.sleep(for: .milliseconds(300))
    }

    /// Add to Anki after a real lookup. Whatever the isolated backend answers — usually
    /// "not set up", since its configuration is fresh — is what gets captured.
    private func ankiScene(appearance: String) async {
        guard let delegate else { return }
        delegate.snapshotPresent(text: environment["TRANSLATOR_DEBUG_ANKI_TEXT"] ?? "serendipity")
        await waitUntil(timeout: 25) { !delegate.model.state.loading }
        try? await Task.sleep(for: .milliseconds(400))
        delegate.showAnkiSheet()
        let opened = delegate.snapshotWindow(id: "anki")?.frame
        // The sheet starts preparing from its own task; let that begin, then finish.
        try? await Task.sleep(for: .milliseconds(500))
        await waitUntil(timeout: 20) { !delegate.model.isPreparingUpsert }
        // The deck list and the form's own measuring pass.
        try? await Task.sleep(for: .milliseconds(1200))
        if let window = delegate.snapshotWindow(id: "anki"), window.isVisible {
            probeReuse("anki", window)
            // Growing from the placeholder to the form must keep the title bar where the
            // user saw it appear, and must not run off the screen.
            if let opened {
                let fixed = abs(opened.maxY - window.frame.maxY) < 1
                let visible = window.screen.map { $0.visibleFrame.contains(window.frame) } ?? false
                NSLog("[snapshot] PROBE anki-top-edge-fixed \(fixed ? "PASS" : "FAIL") \(opened) -> \(window.frame)")
                NSLog("[snapshot] PROBE anki-on-screen \(visible ? "PASS" : "FAIL") \(window.frame) in \(window.screen?.visibleFrame ?? .zero)")
            }
            write(window, "anki-\(appearance)")
            // Esc is the Cancel button's key equivalent.
            window.sendEvent(Self.key(53, "\u{1b}", in: window))
            try? await Task.sleep(for: .milliseconds(300))
            NSLog("[snapshot] PROBE anki-escape-cancels \(window.isVisible ? "FAIL still visible" : "PASS")")
            window.close()
        } else {
            NSLog("[snapshot] anki window not visible")
        }
        delegate.snapshotHidePopup()
        try? await Task.sleep(for: .milliseconds(300))
    }

    /// Window and controller identity from the first open of each window, so the second
    /// appearance can show that reopening reuses both.
    private var firstOpened: [String: (window: ObjectIdentifier, controller: ObjectIdentifier?)] = [:]

    private func probeReuse(_ id: String, _ window: NSWindow) {
        let now = (window: ObjectIdentifier(window), controller: window.contentViewController.map(ObjectIdentifier.init))
        guard let first = firstOpened[id] else {
            firstOpened[id] = now
            return
        }
        let same = first.window == now.window && first.controller == now.controller
        NSLog("[snapshot] PROBE \(id)-reuse \(same ? "PASS" : "FAIL") same window and controller on reopen")
    }

    /// Runs `action` with the popup hidden and reports whether it came up on `text`.
    ///
    /// Up to three attempts: a sibling run or the user may take focus in the middle of a
    /// synthetic click, which says nothing about the list.
    ///
    /// `needsActiveApp`: synthetic clicks on a window of an app the system declined to
    /// activate only ask for activation and never reach the list (a real click activates
    /// the app first). With the app never active, such a probe proves nothing either way
    /// and reports SKIP.
    private func probeOpens(
        _ name: String,
        expecting text: String,
        needsActiveApp: Bool = false,
        _ action: () async -> Void
    ) async {
        guard let delegate else { return }
        var shown = false
        var attempt = 0
        var everActive = false
        while attempt < 3, !(shown && delegate.model.state.originalText == text) {
            attempt += 1
            delegate.snapshotHidePopup()
            try? await Task.sleep(for: .milliseconds(300))
            everActive = everActive || NSApp.isActive
            await action()
            await waitUntil(timeout: 4) {
                delegate.snapshotPopupWindow?.isVisible == true && delegate.model.state.originalText == text
            }
            shown = delegate.snapshotPopupWindow?.isVisible == true
        }
        let opened = shown && delegate.model.state.originalText == text
        let verdict = opened ? "PASS" : (needsActiveApp && !everActive ? "SKIP app never active" : "FAIL")
        NSLog("[snapshot] PROBE \(name) \(verdict) popup \(shown ? "shown" : "hidden") on “\(delegate.model.state.originalText)”, wanted “\(text)”, attempt \(attempt)")
        delegate.snapshotHidePopup()
        try? await Task.sleep(for: .milliseconds(200))
    }

    private static func key(_ code: UInt16, _ characters: String, in window: NSWindow) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
            context: nil, characters: characters, charactersIgnoringModifiers: characters,
            isARepeat: false, keyCode: code
        )!
    }

    /// A double-click on a row, delivered the way the window server would: each mouse-up
    /// is queued before its mouse-down is sent, because the table tracks the press in a
    /// loop that reads the up from the queue.
    ///
    /// A lone click goes first, a double-click interval earlier: when the window was not
    /// key, its first click only makes it key, and a double-click that starts with that
    /// click never reaches the list.
    private static func doubleClick(row: Int, of table: NSTableView, in window: NSWindow) async {
        let rect = table.rect(ofRow: row)
        let point = table.convert(NSPoint(x: rect.midX, y: rect.midY), to: nil)
        click(at: point, count: 1, in: window)
        try? await Task.sleep(for: .seconds(NSEvent.doubleClickInterval + 0.2))
        click(at: point, count: 1, in: window)
        click(at: point, count: 2, in: window)
    }

    private static func click(at point: NSPoint, count: Int, in window: NSWindow) {
        for type in [NSEvent.EventType.leftMouseUp, .leftMouseDown] {
            guard let event = NSEvent.mouseEvent(
                with: type, location: point, modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                context: nil, eventNumber: 0, clickCount: count, pressure: type == .leftMouseDown ? 1 : 0
            ) else { continue }
            if type == .leftMouseUp { NSApp.postEvent(event, atStart: false) } else { window.sendEvent(event) }
        }
    }

    // MARK: - Capture

    private func capturePopup(_ name: String) async {
        guard let window = delegate?.snapshotPopupWindow, window.isVisible else {
            NSLog("[snapshot] popup not visible for \(name)")
            return
        }
        write(window, name)
    }

    /// A settings window is taller than any screen once every section is open, so it is
    /// captured a page at a time by scrolling whatever scroll view holds its content.
    private func captureScrollingPages(_ window: NSWindow, prefix: String) async {
        guard let scroll = Self.largestScrollView(in: window.contentView),
              let document = scroll.documentView
        else {
            write(window, "\(prefix)-0")
            return
        }
        let visible = scroll.contentView.bounds.height
        let total = document.frame.height
        var offset: CGFloat = 0
        var page = 0
        repeat {
            let y = document.isFlipped ? offset : max(0, total - visible - offset)
            scroll.contentView.scroll(to: NSPoint(x: 0, y: y))
            scroll.reflectScrolledClipView(scroll.contentView)
            try? await Task.sleep(for: .milliseconds(350))
            write(window, "\(prefix)-\(page)")
            offset += max(visible - 60, 120)
            page += 1
        } while offset < total - visible + 1 && page < 12
    }

    private func write(_ window: NSWindow, _ name: String) {
        WindowSnapshot.write(window, to: output.appendingPathComponent("\(name).png"))
    }

    private static func largestScrollView(in view: NSView?) -> NSScrollView? {
        guard let view else { return nil }
        var best: NSScrollView?
        var stack = [view]
        while let next = stack.popLast() {
            if let scroll = next as? NSScrollView,
               (scroll.documentView?.frame.height ?? 0) > (best?.documentView?.frame.height ?? 0) {
                best = scroll
            }
            stack.append(contentsOf: next.subviews)
        }
        return best
    }

    private static func firstView<T: NSView>(ofType type: T.Type, in root: NSView?) -> T? {
        var stack = [root].compactMap { $0 }
        while !stack.isEmpty {
            let next = stack.removeFirst()
            if let match = next as? T { return match }
            stack.append(contentsOf: next.subviews)
        }
        return nil
    }

    /// The search field SwiftUI's `.searchable` put into the window's toolbar.
    private static func searchField(in window: NSWindow) -> NSSearchField? {
        if let item = window.toolbar?.items.lazy.compactMap({ $0 as? NSSearchToolbarItem }).first {
            return item.searchField
        }
        var stack = [window.contentView?.superview].compactMap { $0 }
        while let next = stack.popLast() {
            if let field = next as? NSSearchField { return field }
            stack.append(contentsOf: next.subviews)
        }
        return nil
    }

    /// Replaces the field's text through its field editor, the way typing does, so the
    /// view hears about it exactly as it would from the keyboard.
    private static func type(_ text: String, into field: NSSearchField, of window: NSWindow) {
        window.makeFirstResponder(field)
        guard let editor = field.currentEditor() as? NSTextView else { return }
        editor.selectAll(nil)
        if text.isEmpty {
            editor.deleteBackward(nil)
        } else {
            editor.insertText(text, replacementRange: editor.selectedRange())
        }
    }

    private func waitUntil(timeout: TimeInterval, _ condition: () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        // Let a state change that was just requested land before testing it.
        try? await Task.sleep(for: .milliseconds(150))
        while !condition() && Date() < deadline {
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    static func slug(_ text: String) -> String {
        let cleaned = text.lowercased().map { $0.isLetter || $0.isNumber ? $0 : "-" }
        return String(String(cleaned).split(separator: "-").joined(separator: "-").prefix(24))
    }
}
