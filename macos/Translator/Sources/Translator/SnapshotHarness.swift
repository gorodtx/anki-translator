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
/// - `TRANSLATOR_DEBUG_SNAPSHOT_SCENES` — any of `popup,settings,history,anki,probes` (default all).
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
        let raw = environment["TRANSLATOR_DEBUG_SNAPSHOT_SCENES"] ?? "popup,settings,history,anki,probes"
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
                if scenes.contains("probes") { await popupProbes() }
            }
            NSLog("[snapshot] done")
            exit(0)
        }
    }

    // MARK: - Scenes

    /// Beyond the defaults: a word too long for any line, and an entry with dozens of senses.
    private static let popupExtraTexts = ["pneumonoultramicroscopicsilicovolcanoconiosis", "set"]

    private func popupScenes(appearance: String) async {
        guard let delegate else { return }
        let popup = delegate.snapshotPopup
        // Sibling runs and the user's own apps may take focus mid-scene; a capture must
        // not lose its panel to that. The probes scene runs with real dismissal.
        popup.suspendsDismissal = true
        defer { popup.suspendsDismissal = false }
        // The backdrop goes up before the first panel, so the glass adapts to it from its
        // first frame instead of to whatever happened to be on screen.
        backdrop.cover(topLeft: delegate.snapshotPointer)
        var texts = self.texts
        if environment["TRANSLATOR_DEBUG_SNAPSHOT_TEXTS"]?.isEmpty ?? true {
            texts += Self.popupExtraTexts
        }
        // The first frame, before any answer: what the user sees while waiting. A word
        // this run has not looked up yet, so no cached answer beats the capture.
        let waiting = appearance == "dark" ? "ephemeral" : "quintessential"
        delegate.snapshotPresent(text: waiting)
        try? await Task.sleep(for: .milliseconds(16))
        await capturePopup("popup-loading-\(appearance)", settle: false)
        await waitUntil(timeout: 25) { !delegate.model.state.loading }
        for (index, text) in texts.enumerated() {
            let slug = Self.slug(text)
            delegate.snapshotPresent(text: text)
            await waitUntil(timeout: 25) { !delegate.model.state.loading }
            // The resize is event-driven: one turn to measure, 0.2 s of animation.
            try? await Task.sleep(for: .milliseconds(450))
            await capturePopup("popup-\(index)-\(slug)-\(appearance)")
            // A capped entry: the body scrolled, to show it stays clipped between the
            // header and the footer.
            if text == "set", let window = delegate.snapshotPopupWindow,
               let scroll = Self.largestScrollView(in: window.contentView),
               let document = scroll.documentView {
                let visible = scroll.contentView.bounds.height
                let y = document.isFlipped
                    ? document.frame.height * 0.4
                    : max(0, document.frame.height * 0.6 - visible)
                scroll.contentView.scroll(to: NSPoint(x: 0, y: y))
                scroll.reflectScrolledClipView(scroll.contentView)
                try? await Task.sleep(for: .milliseconds(300))
                await capturePopup("popup-\(index)-\(slug)-scrolled-\(appearance)")
            }
        }
        // A banner over a finished card.
        delegate.snapshotPresent(text: "serendipity")
        await waitUntil(timeout: 25) { !delegate.model.state.loading }
        delegate.model.show(banner: "Added to Anki: English::Vocabulary", level: .success)
        try? await Task.sleep(for: .milliseconds(450))
        await capturePopup("popup-banner-\(appearance)")
        // A footer row under the pointer.
        delegate.snapshotPresent(text: "look up")
        await waitUntil(timeout: 25) { !delegate.model.state.loading }
        popup.highlightedRow = .copyTranslation
        try? await Task.sleep(for: .milliseconds(450))
        await capturePopup("popup-hover-\(appearance)")
        popup.highlightedRow = nil
        // A lookup that failed: its reason once, as the body, and no banner repeating it.
        delegate.snapshotPresent(text: "qwzxv")
        await waitUntil(timeout: 25) { !delegate.model.state.loading }
        delegate.model.lastError = "The backend stopped responding."
        delegate.model.show(banner: "The backend stopped responding.", level: .error)
        try? await Task.sleep(for: .milliseconds(450))
        await capturePopup("popup-error-\(appearance)")
        // The announcement path: a bare message, no lookup behind it.
        delegate.snapshotAnnounce("No text selected.", level: .info)
        try? await Task.sleep(for: .milliseconds(400))
        await capturePopup("popup-announce-\(appearance)")
        delegate.snapshotHidePopup()
        backdrop.close()
        try? await Task.sleep(for: .milliseconds(300))
    }

    /// One image per pane, each selected the way the toolbar selects it, plus General with
    /// its Setup checklist showing (a shortcut another app owns, simulated in the model).
    private func settingsScene(appearance: String) async {
        guard let delegate else { return }
        let settings = delegate.snapshotSettingsWindow
        let windowBefore = settings.window
        delegate.showSettings(pane: .general)
        // The window refreshes ping, settings and Anki when it becomes key.
        try? await Task.sleep(for: .seconds(3))
        guard let window = settings.window, window.isVisible else {
            NSLog("[snapshot] settings window not visible")
            return
        }
        NSLog("[snapshot] settings window reused=\(windowBefore === window) key=\(window.isKeyWindow) active=\(NSApp.isActive)")
        for pane in SettingsPaneID.allCases {
            settings.select(pane)
            // The pane switch animates the frame over 0.25 s; Anki asks AnkiConnect.
            try? await Task.sleep(for: .milliseconds(pane == .anki ? 1500 : 700))
            logControls(in: window, name: "settings-\(pane.rawValue)-\(appearance)")
            write(window, "settings-\(pane.rawValue)-\(appearance)")
            if pane == .sources, appearance == appearances.first?.0 {
                await probeAutoSave(in: window)
            }
            // "What runs here?" opened: the pane grows, and the window with it.
            if pane == .advanced {
                let closedHeight = window.frame.height
                let top = window.frame.maxY
                NotificationCenter.default.post(name: AdvancedSettingsPane.snapshotDisclosure, object: true)
                try? await Task.sleep(for: .milliseconds(900))
                NSLog("[snapshot] advanced disclosure: window height \(closedHeight) -> \(window.frame.height), top kept=\(window.frame.maxY == top)")
                write(window, "settings-advanced-open-\(appearance)")
                NotificationCenter.default.post(name: AdvancedSettingsPane.snapshotDisclosure, object: false)
                try? await Task.sleep(for: .milliseconds(700))
            }
        }
        // The checklist appears only while setup is unfinished, which the isolated
        // backend never is; a taken shortcut is the one gap the model can stand in for.
        let registered = delegate.model.shortcutRegistered
        delegate.model.shortcutRegistered = false
        settings.select(.general)
        try? await Task.sleep(for: .milliseconds(900))
        logControls(in: window, name: "settings-general-setup-\(appearance)")
        write(window, "settings-general-setup-\(appearance)")
        delegate.model.shortcutRegistered = registered
        try? await Task.sleep(for: .milliseconds(500))
        // Closed the way a user closes it from the keyboard.
        if let commandW = NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: .command,
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
            context: nil, characters: "w", charactersIgnoringModifiers: "w", isARepeat: false, keyCode: 13
        ) {
            let handled = window.performKeyEquivalent(with: commandW)
            try? await Task.sleep(for: .milliseconds(300))
            NSLog("PROBE settings-close-command-w \(handled && !window.isVisible ? "PASS" : "FAIL") handled=\(handled) visible=\(window.isVisible)")
        }
        window.close()
        try? await Task.sleep(for: .milliseconds(300))
    }

    /// A click on a source's checkbox reaches the backend's config file with no Save
    /// button, and a second click puts it back. The config lives where `snapshot.sh`
    /// points the isolated backend.
    private func probeAutoSave(in window: NSWindow) async {
        guard let delegate else { return }
        let config = output.appendingPathComponent(".backend/cfg/desktop_config.json")
        func stored() -> Bool? {
            guard let data = try? Data(contentsOf: config),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let sources = json["sources"] as? [String: Any]
            else { return nil }
            return sources["cambridge"] as? Bool
        }
        // The fourth checkbox from the top is Cambridge.
        let boxes = Self.checkboxes(in: window)
        guard boxes.count == 6 else {
            NSLog("PROBE settings-autosave FAIL found \(boxes.count) checkboxes, expected 6")
            return
        }
        // SwiftUI's checkbox is drawn by an NSButton that has no action of its own, so the
        // probe clicks the way the mouse does.
        let box = boxes[3].convert(boxes[3].bounds, to: nil)
        let before = delegate.model.settings.sources.cambridge
        var results: [String] = []
        var passed = true
        // Off, then on again; with the window key the second click goes on the title.
        // A window that is not key takes a first click on text only to come forward (the
        // checkbox itself accepts it), and the harness cannot activate the app while
        // another one is in front, so then both clicks go on the box.
        for (step, expected) in [(0, !before), (1, before)] {
            let onTitle = step == 1 && window.isKeyWindow
            let point = onTitle ? NSPoint(x: box.maxX + 24, y: box.midY) : NSPoint(x: box.midX, y: box.midY)
            Self.click(at: point, in: window)
            try? await Task.sleep(for: .milliseconds(1500))
            let model = delegate.model.settings.sources.cambridge
            let file = stored()
            passed = passed && model == expected && file == expected
            results.append("\(onTitle ? "title" : "box") click: model=\(model) file=\(file.map(String.init) ?? "nil") expected=\(expected)")
        }
        NSLog("PROBE settings-autosave \(passed ? "PASS" : "FAIL") \(results.joined(separator: "; "))")
        if delegate.model.settings.sources.cambridge != before {
            // Never leave the run's backend with a source switched off.
            delegate.model.settings.sources.cambridge = before
            try? await Task.sleep(for: .milliseconds(1000))
        }
    }

    /// A left click at a point in window coordinates. The mouse-up is queued first: a
    /// button tracks the mouse in a loop of its own and would wait for it forever.
    private static func click(at point: NSPoint, in window: NSWindow) {
        func event(_ type: NSEvent.EventType) -> NSEvent? {
            NSEvent.mouseEvent(
                with: type, location: point, modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                context: nil, eventNumber: 0, clickCount: 1, pressure: type == .leftMouseDown ? 1 : 0
            )
        }
        guard let down = event(.leftMouseDown), let up = event(.leftMouseUp) else { return }
        NSApp.postEvent(up, atStart: false)
        window.sendEvent(down)
    }

    /// The window's checkboxes, top to bottom.
    private static func checkboxes(in window: NSWindow) -> [NSButton] {
        var stack = [window.contentView].compactMap { $0 }
        var found: [(CGFloat, NSButton)] = []
        while let view = stack.popLast() {
            if let button = view as? NSButton, button.frame.width < 30,
               !(button.cell is NSSearchFieldCell), button.accessibilityRole() != .button {
                found.append((button.convert(button.bounds, to: nil).maxY, button))
            }
            stack.append(contentsOf: view.subviews)
        }
        return found.sorted { $0.0 > $1.0 }.map(\.1)
    }

    /// Where every checkbox and button of a window sits, in points from the content's
    /// left edge, so alignment can be checked against the image.
    private func logControls(in window: NSWindow, name: String) {
        var stack = [window.contentView].compactMap { $0 }
        var lines: [String] = []
        while let view = stack.popLast() {
            if view.accessibilityRole() == .checkBox || view is NSButton {
                let frame = view.convert(view.bounds, to: nil)
                let top = window.contentLayoutRect.maxY - frame.maxY
                let role = view.accessibilityRole()?.rawValue ?? "?"
                let label = view.accessibilityLabel() ?? (view as? NSButton)?.title ?? ""
                lines.append(String(format: "%@ x=%.1f y=%.1f w=%.1f '%@'", role, frame.minX, top, frame.width, label))
            }
            stack.append(contentsOf: view.subviews)
        }
        NSLog("[snapshot] controls \(name): \(lines.sorted().joined(separator: " | "))")
    }

    /// The list as the popup scenes left it (or its empty state on a fresh backend), then
    /// the no-match state, reached by typing into the toolbar's own search field.
    private func historyScene(appearance: String) async {
        guard let delegate else { return }
        delegate.showHistory()
        try? await Task.sleep(for: .seconds(2))
        guard let window = delegate.snapshotWindow(id: "history") else { return }
        let reopened = firstOpened["history"] != nil
        probeReuse("history", window)
        // The frame is autosaved; a size left by an earlier run must not change the image.
        window.setContentSize(HistoryView.defaultSize)
        if reopened, !delegate.model.history.isEmpty {
            // The popup scenes of this appearance added a row at the top while the window
            // was closed: the newest row must still open fully below the toolbar.
            try? await Task.sleep(for: .milliseconds(300))
            Self.probeFirstRow("history-first-row-on-reopen", in: window)
        }
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
            await historyReopenAfterLookup(window, appearance: appearance)
            await historyFailures(window, appearance: appearance)
        }
        window.close()
        try? await Task.sleep(for: .milliseconds(300))
    }

    /// What a user does between two looks at History: close it, look a new word up, open
    /// it again. The new word is the first row, fully in view below the toolbar.
    private func historyReopenAfterLookup(_ window: NSWindow, appearance: String) async {
        guard let delegate else { return }
        window.close()
        try? await Task.sleep(for: .milliseconds(300))
        let word = appearance == "dark" ? "gregarious" : "meticulous"
        let popup = delegate.snapshotPopup
        popup.suspendsDismissal = true
        delegate.snapshotPresent(text: word)
        await waitUntil(timeout: 25) { !delegate.model.state.loading }
        popup.suspendsDismissal = false
        delegate.snapshotHidePopup()
        try? await Task.sleep(for: .milliseconds(300))
        delegate.showHistory()
        Self.probeFirstRow("history-scroll-at-show", in: window, log: false)
        await waitUntil(timeout: 5) { delegate.model.history.first?.text == word }
        Self.probeFirstRow("history-scroll-after-load", in: window, log: false)
        try? await Task.sleep(for: .milliseconds(700))
        let newest = delegate.model.history.first?.text == word
        Self.probeFirstRow(
            "history-first-row-after-lookup", in: window,
            problem: newest ? nil : "the newest row is not “\(word)”"
        )
        write(window, "history-reopened-\(appearance)")
    }

    /// History when the backend lets it down.
    ///
    /// Opening an entry the backend refuses is real: no entry has id -1, and the backend
    /// answers "No history entry -1.". A failed load cannot be had from a running backend,
    /// so its state (no rows, the client's own "not connected" words) is set on the model;
    /// the Try Again that follows is a real reload.
    private func historyFailures(_ window: NSWindow, appearance: String) async {
        guard let delegate else { return }
        let model = delegate.model

        // An entry that cannot be opened: no popup over the previous lookup, the reason
        // in this window.
        delegate.snapshotHidePopup()
        model.historyOpenFailure = nil
        let before = model.state.originalText
        delegate.showHistoryEntry(-1)
        await waitUntil(timeout: 4) { model.historyOpenFailure != nil }
        try? await Task.sleep(for: .milliseconds(500))
        let popupShown = delegate.snapshotPopupWindow?.isVisible == true
        let alert = window.attachedSheet
        let opened = model.historyOpenFailure != nil && !popupShown && alert != nil
        NSLog("[snapshot] PROBE history-open-failure \(opened ? "PASS" : "FAIL") popup \(popupShown ? "shown" : "hidden"), alert \(alert == nil ? "none" : "shown"), message “\(model.historyOpenFailure?.message ?? "-")”, state still “\(model.state.originalText)” (was “\(before)”)")
        if let alert {
            write(alert, "history-open-failed-\(appearance)")
            // Return is the alert's default button.
            alert.sendEvent(Self.key(36, "\r", in: alert))
            await waitUntil(timeout: 3) { window.attachedSheet == nil && model.historyOpenFailure == nil }
            let gone = window.attachedSheet == nil && model.historyOpenFailure == nil
            NSLog("[snapshot] PROBE history-open-failure-dismissed \(gone ? "PASS" : "FAIL") sheet \(window.attachedSheet == nil ? "gone" : "still shown")")
        }
        model.historyOpenFailure = nil

        // A load that failed with nothing to show: not "No History".
        let rows = model.history.count
        model.history = []
        model.historyLoadError = "Backend is not connected."
        try? await Task.sleep(for: .milliseconds(500))
        write(window, "history-error-\(appearance)")
        // Pressed the way VoiceOver presses it: SwiftUI's button is no NSButton.
        let pressed = Self.pressButton(titled: "Try Again", in: window)
        await waitUntil(timeout: 5) { !model.history.isEmpty }
        let recovered = pressed && model.history.count == rows && model.historyLoadError == nil
        NSLog("[snapshot] PROBE history-load-error-retry \(recovered ? "PASS" : "FAIL") button \(pressed ? "pressed" : "missing"), rows \(model.history.count) of \(rows), error \(model.historyLoadError ?? "none")")
        if !recovered {
            model.historyLoadError = nil
            await model.loadHistory()
        }
        try? await Task.sleep(for: .milliseconds(300))
    }

    /// Finds a button by its accessibility title and presses it through accessibility.
    private static func pressButton(titled title: String, in window: NSWindow) -> Bool {
        // SwiftUI's own elements are not declared as NSAccessibility conformers, so they
        // are asked by message rather than by protocol.
        var stack: [AnyObject] = [window.contentView].compactMap { $0 }
        var visited = 0
        while let element = stack.popLast(), visited < 5000 {
            visited += 1
            let role = element.accessibilityRole?() ?? nil
            let names = [element.accessibilityTitle?() ?? nil, element.accessibilityLabel?() ?? nil]
            if role == .button, names.contains(title) {
                return element.accessibilityPerformPress?() ?? false
            }
            let children = element.accessibilityChildren?() ?? nil
            stack.append(contentsOf: (children ?? []).map { $0 as AnyObject })
        }
        return false
    }

    /// Whether the list's first row is fully visible below the toolbar with the list at its
    /// top. With `log: false` it records the geometry only, for diagnosis.
    private static func probeFirstRow(_ name: String, in window: NSWindow, log: Bool = true, problem: String? = nil) {
        guard let table = firstView(ofType: NSTableView.self, in: window.contentView),
              let scroll = table.enclosingScrollView else {
            NSLog("[snapshot] PROBE \(name) FAIL no list in the window")
            return
        }
        guard table.numberOfRows > 0 else {
            NSLog("[snapshot] PROBE \(name) FAIL the list is empty")
            return
        }
        let row = table.convert(table.rect(ofRow: 0), to: nil)
        let clip = scroll.contentView
        let visibleTop = clip.convert(clip.bounds, to: nil).maxY
        let insetTop = scroll.contentInsets.top
        let atTop = clip.bounds.origin.y <= -insetTop + 0.5
        let inView = row.maxY <= min(visibleTop - insetTop, window.contentLayoutRect.maxY) + 0.5
        let geometry = "row0 top \(row.maxY), clip top \(visibleTop), layout top \(window.contentLayoutRect.maxY), "
            + "clip y \(clip.bounds.origin.y), inset \(insetTop), rows \(table.numberOfRows)"
        guard log else {
            NSLog("[snapshot] \(name): \(geometry)")
            return
        }
        let ok = atTop && inView && problem == nil
        NSLog("[snapshot] PROBE \(name) \(ok ? "PASS" : "FAIL") \(problem.map { $0 + "; " } ?? "")\(geometry)")
    }

    /// Add to Anki after a real lookup. Whatever the isolated backend answers — usually
    /// "not set up", since its configuration is fresh — is what gets captured.
    private func ankiScene(appearance: String) async {
        guard let delegate else { return }
        await configureAnkiStandIn()
        delegate.snapshotPresent(text: ankiText)
        await waitUntil(timeout: 25) { !delegate.model.state.loading }
        try? await Task.sleep(for: .milliseconds(400))
        delegate.showAnkiSheet()
        let opened = delegate.snapshotWindow(id: "anki")?.frame
        // The sheet starts preparing from its own task; let that begin, then finish.
        try? await Task.sleep(for: .milliseconds(500))
        await waitUntil(timeout: 20) { Self.ankiSettled(delegate.model) }
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
        await ankiFollowsNewLookup(appearance: appearance)
    }

    private var ankiText: String { environment["TRANSLATOR_DEBUG_ANKI_TEXT"] ?? "serendipity" }

    /// Add to Anki has nothing left to do: no preparation out, and not waiting on a lookup.
    private static func ankiSettled(_ model: AppModel) -> Bool {
        !model.isPreparingUpsert && model.ankiNoteSource?.finished != false
    }

    /// `TRANSLATOR_DEBUG_ANKI_STUB=1`: an AnkiConnect stand-in answers at `ANKI_CONNECT_URL`
    /// with a deck "English::Vocabulary" and a note type "Translator". The isolated
    /// backend is pointed at both, so the sheet shows its form and Add really adds.
    private var ankiStandIn: Bool { environment["TRANSLATOR_DEBUG_ANKI_STUB"] == "1" }

    private func configureAnkiStandIn() async {
        guard ankiStandIn, let model = delegate?.model else { return }
        guard model.settings.anki.deck.isEmpty || model.settings.anki.model.isEmpty else { return }
        model.settings.anki.deck = "English::Vocabulary"
        model.settings.anki.model = "Translator"
        // The debounced save, then the backend's own status check.
        try? await Task.sleep(for: .milliseconds(1200))
        await model.refreshAnkiStatus()
    }

    /// A new lookup while Add to Anki is open drops the note the backend prepared. The
    /// window must follow the new lookup (prepare again from it, with its word in the Word
    /// row) or close; never show one word over another's values with an Add that fails.
    /// Then Esc on the new lookup's popup closes the session, and the window with it.
    private func ankiFollowsNewLookup(appearance: String) async {
        guard let delegate else { return }
        let model = delegate.model
        let popup = delegate.snapshotPopup
        let second = ankiText == "bank" ? "went" : "bank"

        popup.suspendsDismissal = true
        delegate.snapshotPresent(text: ankiText)
        await waitUntil(timeout: 25) { !model.state.loading }
        popup.suspendsDismissal = false
        delegate.showAnkiSheet()
        try? await Task.sleep(for: .milliseconds(500))
        await waitUntil(timeout: 20) { Self.ankiSettled(model) }
        try? await Task.sleep(for: .milliseconds(800))
        guard let window = delegate.snapshotWindow(id: "anki"), window.isVisible else {
            NSLog("[snapshot] PROBE anki-new-lookup-follows FAIL the window did not open")
            return
        }
        let before = model.ankiNoteSource

        // The popup comes up over the open window for another word, as a hot key press does.
        popup.suspendsDismissal = true
        delegate.snapshotPresent(text: second)
        await waitUntil(timeout: 25) { !model.state.loading }
        try? await Task.sleep(for: .milliseconds(500))
        await waitUntil(timeout: 20) { Self.ankiSettled(model) }
        try? await Task.sleep(for: .milliseconds(1000))
        popup.suspendsDismissal = false
        let after = model.ankiNoteSource
        let followed = window.isVisible && after?.text == second && after?.requestId == model.activeRequestId
        let closed = !window.isVisible && after == nil
        let what = followed ? "prepared again for “\(second)”" : closed ? "closed" : "stale"
        NSLog("[snapshot] PROBE anki-new-lookup-follows \(followed || closed ? "PASS" : "FAIL") \(what): before “\(before?.text ?? "-")” #\(before?.requestId ?? -1), now “\(after?.text ?? "-")” #\(after?.requestId ?? -1), lookup “\(model.state.originalText)” #\(model.activeRequestId), preview \(model.upsertPreview == nil ? "none" : "ready")")
        guard window.isVisible else { return }
        write(window, "anki-new-lookup-\(appearance)")

        if ankiStandIn {
            // Return is the default button: Add must now succeed, for the new word.
            window.sendEvent(Self.key(36, "\r", in: window))
            await waitUntil(timeout: 10) { !window.isVisible }
            let banner = model.banner
            let added = !window.isVisible && banner?.level == .success
            NSLog("[snapshot] PROBE anki-add-after-new-lookup \(added ? "PASS" : "FAIL") window \(window.isVisible ? "open" : "closed"), banner “\(banner?.text ?? "-")”")
            delegate.snapshotHidePopup()
            try? await Task.sleep(for: .milliseconds(300))
            delegate.showAnkiSheet()
            try? await Task.sleep(for: .milliseconds(500))
            await waitUntil(timeout: 20) { Self.ankiSettled(model) }
            try? await Task.sleep(for: .milliseconds(500))
        } else {
            NSLog("[snapshot] PROBE anki-add-after-new-lookup SKIP no AnkiConnect stand-in (TRANSLATOR_DEBUG_ANKI_STUB)")
        }

        // Esc on the popup ends the session, and the backend forgets the prepared note.
        var detail = "popup not shown"
        var passed = false
        for attempt in 1...3 where window.isVisible {
            delegate.snapshotReshowPopup()
            try? await Task.sleep(for: .milliseconds(300))
            guard let panel = delegate.snapshotPopupWindow, panel.isVisible else { continue }
            let sessions = popup.sessionsEnded
            panel.sendEvent(Self.escape(for: panel))
            await waitUntil(timeout: 3) { !window.isVisible }
            // The closed window drops its content on the next turn.
            try? await Task.sleep(for: .milliseconds(300))
            let ended = popup.sessionsEnded - sessions
            passed = ended == 1 && !window.isVisible && model.ankiNoteSource == nil
            detail = "closeSession=+\(ended) window \(window.isVisible ? "open" : "closed") attempt=\(attempt)"
            if ended == 1 { break }
        }
        NSLog("[snapshot] PROBE anki-session-close-closes \(passed ? "PASS" : "FAIL") \(detail)")
        window.close()
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

    private let backdrop = PopupBackdrop()

    /// The panel composited over a backdrop of our own, so its glass has something to
    /// show: what a user sees over a real document.
    private func capturePopup(_ name: String, settle: Bool = true) async {
        guard let window = delegate?.snapshotPopupWindow, window.isVisible else {
            NSLog("[snapshot] popup not visible for \(name)")
            return
        }
        if !backdrop.covers(window.frame) {
            backdrop.place(around: window)
            // Let the glass sample (and adapt to) the new backdrop.
            try? await Task.sleep(for: .milliseconds(400))
        } else if settle {
            try? await Task.sleep(for: .milliseconds(100))
        }
        guard window.isVisible else {
            NSLog("[snapshot] popup not visible for \(name)")
            return
        }
        if let state = delegate?.model.state {
            NSLog("[snapshot] state for \(name): original='\(state.originalText.prefix(20))' loading=\(state.loading) translation=\(state.hasTranslation) canAnki=\(state.canAddAnki) banner=\(delegate?.model.banner?.text ?? "-")")
        }
        let url = output.appendingPathComponent("\(name).png")
        // The window server now and then answers a composite with a blank image (neither
        // window in it); that is the capture failing, so it is taken again.
        for attempt in 1...3 {
            if backdrop.write(panel: window, to: url) != .blank { return }
            NSLog("[snapshot] blank composite for \(name), attempt \(attempt)")
            try? await Task.sleep(for: .milliseconds(150))
        }
    }

    // MARK: - Behaviour probes

    private var probesRan = false

    /// Drives the panel's dismissal rules directly and logs `PROBE <name> PASS|FAIL <detail>`.
    ///
    /// Runs with real dismissal. Another app may take focus at any moment during a run
    /// (sibling runs, the user), so a probe whose panel was not key when it started is
    /// retried, up to three attempts.
    private func popupProbes() async {
        guard !probesRan, let delegate else { return }
        probesRan = true
        let popup = delegate.snapshotPopup
        popup.suspendsDismissal = false
        backdrop.close()
        delegate.snapshotPresent(text: "bank")
        await waitUntil(timeout: 25) { !delegate.model.state.loading }
        try? await Task.sleep(for: .milliseconds(400))

        await probe("key-after-show") { panel in
            (panel.isKeyWindow && panel.isVisible, "isKeyWindow=\(panel.isKeyWindow) visible=\(panel.isVisible)")
        }

        await probe("esc-hides") { panel in
            let sessions = popup.sessionsEnded
            panel.sendEvent(Self.escape(for: panel))
            try? await Task.sleep(for: .milliseconds(200))
            let ended = popup.sessionsEnded - sessions
            return (
                !panel.isVisible && popup.lastHideReason == .dismissed && ended == 1,
                "visible=\(panel.isVisible) reason=\(Self.name(popup.lastHideReason)) closeSession=+\(ended) via=panel.sendEvent"
            )
        }

        await probe("esc-hides-from-event-queue") { panel in
            let sessions = popup.sessionsEnded
            NSApp.postEvent(Self.escape(for: panel), atStart: false)
            try? await Task.sleep(for: .milliseconds(300))
            let ended = popup.sessionsEnded - sessions
            return (
                !panel.isVisible && popup.lastHideReason == .dismissed && ended == 1,
                "visible=\(panel.isVisible) reason=\(Self.name(popup.lastHideReason)) closeSession=+\(ended) via=NSApp.postEvent"
            )
        }

        await probe("own-window-hides-quietly") { panel in
            let sessions = popup.sessionsEnded
            let other = ProbeKeyPanel()
            other.setFrameOrigin(NSPoint(x: panel.frame.maxX + 40, y: panel.frame.maxY - 80))
            other.makeKeyAndOrderFront(nil)
            try? await Task.sleep(for: .milliseconds(300))
            let otherWasKey = other.isKeyWindow
            other.orderOut(nil)
            let ended = popup.sessionsEnded - sessions
            return (
                otherWasKey && !panel.isVisible && popup.lastHideReason == .ownWindowFocused && ended == 0,
                "otherKey=\(otherWasKey) visible=\(panel.isVisible) reason=\(Self.name(popup.lastHideReason)) closeSession=+\(ended)"
            )
        }

        await probe("global-mouse-down-hides") { panel in
            let sessions = popup.sessionsEnded
            popup.outsideMouseDown()
            try? await Task.sleep(for: .milliseconds(150))
            let ended = popup.sessionsEnded - sessions
            return (
                !panel.isVisible && popup.lastHideReason == .dismissed && ended == 1,
                "visible=\(panel.isVisible) reason=\(Self.name(popup.lastHideReason)) closeSession=+\(ended) via=global monitor handler"
            )
        }

        await probe("second-hotkey-press-closes") { panel in
            // The hot key pressed again over the open card. The capture stands in for the
            // selection; it must not even be asked, since with the panel key the ⌘C
            // fallback would copy from the panel and wipe the card.
            let sessions = popup.sessionsEnded
            let before = delegate.model.state.originalText
            var captures = 0
            delegate.snapshotHotKeyPress { captures += 1; return nil }
            try? await Task.sleep(for: .milliseconds(200))
            let ended = popup.sessionsEnded - sessions
            let after = delegate.model.state.originalText
            return (
                captures == 0 && !panel.isVisible && popup.lastHideReason == .dismissed && ended == 1 && after == before,
                "captures=\(captures) visible=\(panel.isVisible) reason=\(Self.name(popup.lastHideReason)) closeSession=+\(ended) card “\(before)”→“\(after)”"
            )
        }

        await probeKeyboardScroll()

        await probe("click-inside-keeps") { panel in
            // On the headword, in window coordinates (origin bottom-left).
            let point = NSPoint(x: 40, y: panel.frame.height - 24)
            // Both through the event queue: a mouse-down on selectable text starts a
            // tracking loop that waits for its mouse-up.
            for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                if let event = NSEvent.mouseEvent(
                    with: type, location: point, modifierFlags: [],
                    timestamp: ProcessInfo.processInfo.systemUptime,
                    windowNumber: panel.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1
                ) {
                    NSApp.postEvent(event, atStart: false)
                }
            }
            try? await Task.sleep(for: .milliseconds(300))
            let responder = panel.firstResponder.map { String(describing: Swift.type(of: $0)) } ?? "nil"
            return (panel.isVisible, "visible=\(panel.isVisible) isKeyWindow=\(panel.isKeyWindow) firstResponder=\(responder)")
        }

        // After the click above left a text view first responder: a new showing must
        // give the arrows back to the footer.
        await probeFooterArrows()
        await probeFooterAccessibility()
        await probeMonitorsLifecycle()
        await probeAnnouncementsStayOffKey()
        await probeNoEmptyGlass()
        probeSpoken()

        // The announcement path closes itself (info: 2.5 s) and ends no session. This
        // probe is about that timer alone, so outside focus changes during the 3 s wait
        // are kept from dismissing it (they are what the probes above test).
        popup.suspendsDismissal = true
        defer { popup.suspendsDismissal = false }
        var detail = ""
        var passed = false
        for attempt in 1...3 {
            delegate.snapshotHidePopup()
            let sessions = popup.sessionsEnded
            delegate.snapshotAnnounce("No text selected.", level: .info)
            try? await Task.sleep(for: .milliseconds(3200))
            let visible = delegate.snapshotPopupWindow?.isVisible ?? false
            let ended = popup.sessionsEnded - sessions
            passed = !visible && popup.lastHideReason == .announcementEnded && ended == 0
            detail = "visible=\(visible) reason=\(Self.name(popup.lastHideReason)) closeSession=+\(ended) attempt=\(attempt)"
            if passed || popup.lastHideReason != .dismissed { break }
            detail += " (dismissed by focus taken from outside)"
        }
        NSLog("PROBE announcement-auto-hides \(passed ? "PASS" : "FAIL") \(detail)")
        delegate.snapshotHidePopup()
    }

    /// Page Down, End, Space and Home on a capped body, sent to the panel as the window
    /// server would deliver them to the key window.
    private func probeKeyboardScroll() async {
        await probe("keyboard-scroll") { panel in
            guard let delegate = self.delegate else { return (false, "no delegate") }
            let popup = delegate.snapshotPopup
            guard popup.bodyScrolls, let scroll = popup.bodyScrollView else {
                let s = delegate.model.state
                return (false, "body not capped (bodyScrolls=\(popup.bodyScrolls)); nothing to scroll; state “\(s.originalText)” loading=\(s.loading) translation=\(s.hasTranslation) error=\(delegate.model.lastError ?? "-") frame=\(panel.frame)")
            }
            // Scrolling is under test, not dismissal: focus taken from outside (a sibling
            // run, the user) during the key presses must not hide the panel.
            popup.suspendsDismissal = true
            defer { popup.suspendsDismissal = false }
            @MainActor func offset() -> CGFloat { scroll.contentView.bounds.minY }
            @MainActor func press(_ code: UInt16, _ characters: String) async {
                panel.sendEvent(Self.key(code, characters, in: panel))
                try? await Task.sleep(for: .milliseconds(120))
            }
            let top = offset()
            await press(121, "\u{F72D}")  // Page Down
            let paged = offset()
            await press(119, "\u{F72B}")  // End
            let end = offset()
            await press(115, "\u{F729}")  // Home
            let home = offset()
            await press(49, " ")  // Space
            let spaced = offset()
            await press(115, "\u{F729}")
            let flipped = scroll.documentView?.isFlipped ?? true
            let down: (CGFloat, CGFloat) -> Bool = { flipped ? $1 > $0 + 1 : $1 < $0 - 1 }
            let passed = down(top, paged) && (down(paged, end) || abs(paged - end) < 1) && abs(home - top) < 1
                && down(top, spaced) && panel.isVisible
            return (
                passed,
                String(format: "top=%.0f pageDown=%.0f end=%.0f home=%.0f space=%.0f flipped=%@ visible=%@",
                       top, paged, end, home, spaced, "\(flipped)", "\(panel.isVisible)")
            )
        }
    }

    /// ↑/↓ move the highlight through the enabled footer rows; Return runs the highlighted
    /// one. Return is pressed only on New Examples: Copy Translation would write to the
    /// user's real pasteboard.
    private func probeFooterArrows() async {
        await probe("footer-arrow-keys") { panel in
            guard let delegate = self.delegate else { return (false, "no delegate") }
            let popup = delegate.snapshotPopup
            let rows = PopupFooter.rows(for: delegate.model).map { ($0.row, $0.enabled) }
            @MainActor func press(_ code: UInt16, _ characters: String) async -> PopupFooterRow? {
                panel.sendEvent(Self.key(code, characters, in: panel))
                try? await Task.sleep(for: .milliseconds(80))
                return popup.highlightedRow
            }
            var expected: PopupFooterRow? = nil
            var trail: [String] = []
            var passed = popup.highlightedRow == nil
            for (code, chars, step) in [(125, "\u{F701}", 1), (125, "\u{F701}", 1), (126, "\u{F700}", -1), (125, "\u{F701}", 1)] {
                expected = PopupFooterNavigation.move(from: expected, step: step, rows: rows)
                let got = await press(UInt16(code), chars)
                trail.append(got?.rawValue ?? "none")
                passed = passed && got == expected
            }
            let skipsDisabled = rows.filter { !$0.1 }.allSatisfy { disabled in !trail.contains(disabled.0.rawValue) }
            passed = passed && skipsDisabled && expected != nil
            var activated = "not pressed"
            if popup.highlightedRow == .newExamples {
                panel.sendEvent(Self.key(36, "\r", in: panel))
                try? await Task.sleep(for: .milliseconds(150))
                activated = popup.lastActivatedRow?.rawValue ?? "none"
                passed = passed && popup.lastActivatedRow == .newExamples
            }
            let enabled = rows.map { "\($0.0.rawValue)=\($0.1 ? "on" : "off")" }.joined(separator: ",")
            return (passed, "rows[\(enabled)] highlight ↓↓↑↓ → \(trail.joined(separator: "→")) return→\(activated)")
        }
    }

    /// VoiceOver hears each footer row's shortcut: the glyphs are hidden from it, so the
    /// row's hint carries the shortcut in words (or why the row is disabled).
    ///
    /// SwiftUI builds its accessibility elements only for a connected assistive client;
    /// without one the walk finds no rows and the probe says SKIP (the words themselves
    /// are covered by `PopupSpeechTests.shortcutsAreSpokenAsWords`).
    private func probeFooterAccessibility() async {
        guard let delegate else { return }
        delegate.snapshotHidePopup()
        delegate.snapshotReshowPopup()
        try? await Task.sleep(for: .milliseconds(300))
        guard let panel = delegate.snapshotPopupWindow else { return }
        var found: [String: String] = [:]
        // From the window down, through AppKit views and SwiftUI's own elements.
        var stack: [Any] = [panel]
        var visited = 0
        while let next = stack.popLast(), visited < 4000 {
            visited += 1
            if let view = next as? NSView { stack.append(contentsOf: view.subviews) }
            guard let element = next as? NSAccessibilityProtocol else { continue }
            if let label = element.accessibilityLabel(), PopupFooterRow.allCases.contains(where: { $0.title == label }) {
                found[label] = element.accessibilityHelp() ?? ""
            }
            stack.append(contentsOf: element.accessibilityChildren() ?? [])
        }
        guard !found.isEmpty else {
            NSLog("PROBE footer-accessibility-hints SKIP no SwiftUI accessibility elements without an assistive client (\(visited) AppKit elements walked)")
            return
        }
        let copy = found[PopupFooterRow.copyTranslation.title]
        let examples = found[PopupFooterRow.newExamples.title]
        let passed = copy == "Shift-Command-C" && (examples == nil || examples == "Command-R")
        let listed = found.sorted { $0.key < $1.key }.map { "\($0.key)=“\($0.value)”" }.joined(separator: ", ")
        NSLog("PROBE footer-accessibility-hints \(passed ? "PASS" : "FAIL") \(listed)")
    }

    /// The dismissal monitors exist exactly while the panel is on screen: installed on
    /// show, kept (not replaced) by a new lookup while open, gone after every kind of hide.
    private func probeMonitorsLifecycle() async {
        guard let delegate else { return }
        let popup = delegate.snapshotPopup
        var lines: [String] = []
        var passed = true
        /// Shown and key; an outside focus change right after showing hides it again, so
        /// up to three tries.
        @MainActor func shown() async -> PopupPanelController.MonitorState {
            for _ in 1...3 {
                delegate.snapshotHidePopup()
                delegate.snapshotReshowPopup()
                try? await Task.sleep(for: .milliseconds(250))
                if popup.isKey { break }
            }
            return popup.monitorState
        }
        let hides: [(String, (NSWindow) async -> Void)] = [
            ("esc", { panel in panel.sendEvent(Self.escape(for: panel)) }),
            ("own-window", { panel in
                let other = ProbeKeyPanel()
                other.setFrameOrigin(NSPoint(x: panel.frame.maxX + 40, y: panel.frame.maxY - 80))
                other.makeKeyAndOrderFront(nil)
                try? await Task.sleep(for: .milliseconds(250))
                other.orderOut(nil)
            }),
            ("outside-click", { _ in popup.outsideMouseDown() }),
            ("programmatic", { _ in delegate.snapshotHidePopup() }),
        ]
        for (name, hide) in hides {
            var ok = false
            var line = ""
            for attempt in 1...3 {
                let open = await shown()
                let installs = open.installs
                // A new lookup while the panel is open keeps the monitors it has.
                delegate.snapshotReshowPopup()
                try? await Task.sleep(for: .milliseconds(150))
                let reshown = popup.monitorState
                guard let panel = delegate.snapshotPopupWindow else { break }
                // Focus taken from outside hid it before the hide under test: try again.
                let interfered = !panel.isVisible
                await hide(panel)
                try? await Task.sleep(for: .milliseconds(200))
                let closed = popup.monitorState
                ok = open.all && reshown.all && reshown.installs == installs && !panel.isVisible && closed.none
                line = "\(name)\(ok ? "" : " ✗"): open[\(open)] reshown[\(reshown)] hidden(\(Self.name(popup.lastHideReason)))[\(closed)] attempt=\(attempt)"
                if ok || !interfered { break }
            }
            passed = passed && ok
            lines.append(line)
        }
        // The announcement: installed although it never takes key, gone when its timer ends.
        delegate.snapshotAnnounce("No text selected.", level: .info)
        try? await Task.sleep(for: .milliseconds(250))
        let announcing = popup.monitorState
        await waitUntil(timeout: 4) { delegate.snapshotPopupWindow?.isVisible == false }
        let ended = popup.monitorState
        let ok = announcing.global && ended.none && popup.lastHideReason == .announcementEnded
        passed = passed && ok
        lines.append("announcement: open[\(announcing)] hidden(\(Self.name(popup.lastHideReason)))[\(ended)]")
        NSLog("PROBE monitors-lifecycle \(passed ? "PASS" : "FAIL") \(lines.joined(separator: " | "))")
    }

    /// An announcement leaves keyboard focus where it was — even over a card that had it —
    /// and a hot key press over it runs the capture (the user's app has focus again).
    private func probeAnnouncementsStayOffKey() async {
        await probe("announcement-not-key") { panel in
            guard let delegate = self.delegate else { return (false, "no delegate") }
            let wasKey = panel.isKeyWindow
            delegate.snapshotAnnounce("No text selected.", level: .info)
            try? await Task.sleep(for: .milliseconds(300))
            let visible = panel.isVisible, key = panel.isKeyWindow
            let keyNow = NSApp.keyWindow.map { String(describing: Swift.type(of: $0)) } ?? "none"
            let reason = Self.name(delegate.snapshotPopup.lastHideReason)
            return (wasKey && visible && !key, "keyBefore=\(wasKey) visible=\(visible) isKeyWindow=\(key) appKeyWindow=\(keyNow) lastHide=\(reason)")
        }
        await probe("hotkey-over-announcement-captures") { panel in
            guard let delegate = self.delegate else { return (false, "no delegate") }
            // What the press does is under test, not dismissal: a sibling run taking focus
            // during the lookup must not hide the card it opened.
            delegate.snapshotPopup.suspendsDismissal = true
            defer { delegate.snapshotPopup.suspendsDismissal = false }
            delegate.snapshotAnnounce("No text selected.", level: .info)
            try? await Task.sleep(for: .milliseconds(250))
            var captures = 0
            delegate.snapshotHotKeyPress { captures += 1; return "bank" }
            await self.waitUntil(timeout: 10) { !delegate.model.state.loading }
            try? await Task.sleep(for: .milliseconds(200))
            let text = delegate.model.state.originalText
            return (
                captures == 1 && panel.isVisible && panel.isKeyWindow && text == "bank",
                "captures=\(captures) visible=\(panel.isVisible) isKeyWindow=\(panel.isKeyWindow) card=“\(text)”"
            )
        }
    }

    /// A warning announcement (4 s) never shows an empty panel: sampled every 100 ms, the
    /// panel is never on screen without its banner. Then the guard itself: a banner that
    /// goes away early takes the panel with it.
    private func probeNoEmptyGlass() async {
        guard let delegate else { return }
        let popup = delegate.snapshotPopup
        // Only the announcement's own timer and the empty-panel guard may end it here: a
        // click anywhere on the screen (the user, a sibling run) would dismiss it early.
        popup.suspendsDismissal = true
        defer { popup.suspendsDismissal = false }
        delegate.snapshotHidePopup()
        delegate.snapshotAnnounce("⌥⌘T is already taken by another app.", level: .warning)
        let start = Date()
        var emptySamples = 0
        var samples = 0
        while Date().timeIntervalSince(start) < 5 {
            try? await Task.sleep(for: .milliseconds(100))
            let visible = delegate.snapshotPopupWindow?.isVisible ?? false
            if !visible { break }
            samples += 1
            if delegate.model.banner == nil { emptySamples += 1 }
        }
        let lasted = Date().timeIntervalSince(start)
        let timed = emptySamples == 0 && popup.lastHideReason == .announcementEnded && lasted > 3.5
        NSLog("PROBE announcement-no-empty-glass \(timed ? "PASS" : "FAIL") warning shown %.1fs, samples=\(samples) emptySamples=\(emptySamples) reason=\(Self.name(popup.lastHideReason))", lasted)

        delegate.snapshotAnnounce("No text selected.", level: .info)
        try? await Task.sleep(for: .milliseconds(300))
        delegate.model.banner = nil
        try? await Task.sleep(for: .milliseconds(300))
        let visible = delegate.snapshotPopupWindow?.isVisible ?? false
        let guarded = !visible && popup.lastHideReason == .announcementEnded
        NSLog("PROBE empty-panel-hides \(guarded ? "PASS" : "FAIL") banner cleared early → visible=\(visible) reason=\(Self.name(popup.lastHideReason))")
        delegate.snapshotHidePopup()
    }

    /// Results and banners are posted to VoiceOver (whether it speaks them needs VoiceOver
    /// running; the post is what the app controls).
    private func probeSpoken() {
        guard let delegate else { return }
        let spoken = delegate.model.spokenAnnouncements
        let lookup = spoken.contains { $0.hasPrefix("bank: ") }
        let announced = spoken.contains("No text selected.")
        let last = spoken.suffix(4).map { "“\($0.prefix(40))”" }.joined(separator: ", ")
        NSLog("PROBE voiceover-announcements \(lookup && announced ? "PASS" : "FAIL") lookup=\(lookup) announcement=\(announced) last: \(last)")
    }

    /// Show the panel again, wait for it to be key, run `check`; retry when an outside
    /// focus change got in the way.
    private func probe(_ name: String, _ check: (NSWindow) async -> (Bool, String)) async {
        guard let delegate else { return }
        var detail = ""
        for attempt in 1...3 {
            delegate.snapshotHidePopup()
            delegate.snapshotReshowPopup()
            try? await Task.sleep(for: .milliseconds(250))
            guard let panel = delegate.snapshotPopupWindow else { break }
            guard panel.isKeyWindow else {
                detail = "attempt=\(attempt) panel not key before the probe (focus taken from outside)"
                NSLog("[snapshot] probe \(name) retry: \(detail)")
                continue
            }
            let (passed, result) = await check(panel)
            detail = "\(result) attempt=\(attempt)"
            if passed {
                NSLog("PROBE \(name) PASS \(detail)")
                return
            }
            NSLog("[snapshot] probe \(name) retry: \(detail)")
        }
        NSLog("PROBE \(name) FAIL \(detail)")
    }

    private static func escape(for window: NSWindow) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil, characters: "\u{1b}",
            charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: TranslationPanel.escapeKeyCode
        )!
    }

    private static func name(_ reason: PopupHideReason?) -> String { reason?.rawValue ?? "none" }

    private func write(_ window: NSWindow, _ name: String) {
        WindowSnapshot.write(window, to: output.appendingPathComponent("\(name).png"))
    }

    static func largestScrollView(in view: NSView?) -> NSScrollView? {
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

/// Another window of ours that takes key focus without activating the app, standing in
/// for Add to Anki / History / Settings in the focus-rule probe.
private final class ProbeKeyPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 120, height: 60),
            styleMask: [.nonactivatingPanel, .titled],
            backing: .buffered,
            defer: false
        )
        level = .popUpMenu
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { true }
}

/// A window of our own behind the translation panel during popup scenes: a desktop
/// picture with a document page on it, so the captured glass shows what it would over a
/// real screen. It is captured together with the panel as one composited image.
@MainActor
final class PopupBackdrop {
    private var window: NSWindow?
    private static let margin: CGFloat = 44
    private static let captureMargin: CGFloat = 28

    private typealias ArrayCapture = @convention(c) (CGRect, CFArray, UInt32) -> Unmanaged<CGImage>?

    /// `CGWindowListCreateImageFromArray`, obsoleted in the SDK like its sibling but
    /// still answering at runtime for the calling process's own windows.
    private static let capture: ArrayCapture? = {
        guard let symbol = dlsym(dlopen(nil, RTLD_NOW), "CGWindowListCreateImageFromArray") else { return nil }
        return unsafeBitCast(symbol, to: ArrayCapture.self)
    }()

    /// Cover the largest panel that can open with its top-left corner at `topLeft`.
    func cover(topLeft: CGPoint) {
        let size = CGSize(width: PopupLayout.wideWidth, height: PopupLayout.maxHeight)
        let panelArea = CGRect(x: topLeft.x, y: topLeft.y - size.height, width: size.width, height: size.height)
        show(frame: panelArea.insetBy(dx: -Self.margin, dy: -Self.margin), panel: nil)
    }

    func place(around panel: NSWindow) {
        show(frame: panel.frame.insetBy(dx: -Self.margin, dy: -Self.margin), panel: panel)
    }

    func covers(_ frame: CGRect) -> Bool {
        guard let window, window.isVisible else { return false }
        return window.frame.contains(frame.insetBy(dx: -Self.captureMargin, dy: -Self.captureMargin))
    }

    private func show(frame: CGRect, panel: NSWindow?) {
        let window = self.window ?? makeWindow()
        window.appearance = NSApp.appearance
        window.setFrame(frame, display: true)
        window.contentView = NSHostingView(
            rootView: BackdropView(documentWidth: Self.margin + PopupLayout.narrowWidth * 0.62)
        )
        if let panel {
            window.order(.below, relativeTo: panel.windowNumber)
        } else {
            window.orderFrontRegardless()
        }
    }

    func close() {
        window?.orderOut(nil)
    }

    enum WriteResult { case written, blank, failed }

    @discardableResult
    func write(panel: NSWindow, to url: URL) -> WriteResult {
        guard let window, let capture = Self.capture else {
            NSLog("[snapshot] no composited capture for \(url.lastPathComponent); panel alone")
            return WindowSnapshot.write(panel, to: url) ? .written : .failed
        }
        // Global display coordinates: origin at the top-left of the primary screen.
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let area = panel.frame.insetBy(dx: -Self.captureMargin, dy: -Self.captureMargin)
        let rect = CGRect(x: area.minX, y: primaryHeight - area.maxY, width: area.width, height: area.height)
        // Front to back.
        var ids: [UnsafeRawPointer?] = [panel.windowNumber, window.windowNumber].map {
            UnsafeRawPointer(bitPattern: UInt($0))
        }
        guard let array = CFArrayCreate(nil, &ids, ids.count, nil),
              let image = capture(rect, array, 0)?.takeRetainedValue()
        else {
            NSLog("[snapshot] could not capture \(url.lastPathComponent)")
            return .failed
        }
        let bitmap = NSBitmapImageRep(cgImage: image)
        if Self.isBlank(bitmap) { return .blank }
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            NSLog("[snapshot] could not encode \(url.lastPathComponent)")
            return .failed
        }
        do {
            try data.write(to: url)
            NSLog("[snapshot] wrote \(url.lastPathComponent) \(image.width)x\(image.height) panel \(Int(panel.frame.width))x\(Int(panel.frame.height))")
            return .written
        } catch {
            NSLog("[snapshot] write failed: \(error)")
            return .failed
        }
    }

    /// One colour at the centre, the corners and the text column: nothing was composited.
    private static func isBlank(_ bitmap: NSBitmapImageRep) -> Bool {
        let w = bitmap.pixelsWide, h = bitmap.pixelsHigh
        guard w > 4, h > 4 else { return true }
        let points = [(w / 2, h / 2), (2, 2), (w - 3, h - 3), (w / 4, h / 2), (w / 2, h / 4), (3 * w / 4, 3 * h / 4)]
        let colors = points.compactMap { bitmap.colorAt(x: $0.0, y: $0.1) }
        guard let first = colors.first else { return true }
        return colors.allSatisfy { $0 == first }
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
        window.level = .popUpMenu
        window.isReleasedWhenClosed = false
        window.ignoresMouseEvents = true
        window.hasShadow = false
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .ignoresCycle]
        self.window = window
        return window
    }
}

private struct BackdropView: View {
    let documentWidth: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    private var picture: NSImage? {
        let folder = "/System/Library/Desktop Pictures/.thumbnails/"
        let names = colorScheme == .dark
            ? ["Sonoma Dark.heic", "Big Sur Dark.heic", "Big Sur Coastline.heic"]
            : ["Sonoma Light.heic", "Big Sur Coastline.heic"]
        return names.lazy.compactMap { NSImage(contentsOfFile: folder + $0) }.first
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let picture {
                Image(nsImage: picture).resizable().aspectRatio(contentMode: .fill)
            } else {
                LinearGradient(colors: [.blue, .purple], startPoint: .top, endPoint: .bottom)
            }
            VStack(alignment: .leading, spacing: 12) {
                Text("Quarterly Review").font(.title2.weight(.semibold))
                ForEach(0..<8, id: \.self) { index in
                    Text(Self.paragraphs[index % Self.paragraphs.count]).font(.body)
                }
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .frame(width: documentWidth, alignment: .topLeading)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(Color(nsColor: .textBackgroundColor))
            .clipped()
        }
        .clipped()
    }

    private static let paragraphs = [
        "The committee postponed its decision until the auditors had reviewed every account. Several members asked for the figures to be restated before the next meeting.",
        "Revenue grew in every region except the north, where the new warehouse opened late. The board expects the gap to close by the end of the year.",
        "A chance find in the archive turned up the original contracts, which settles the question of who owns the river bank.",
        "Staff went through the ledgers line by line; nothing was set aside without a note explaining why.",
    ]
}
