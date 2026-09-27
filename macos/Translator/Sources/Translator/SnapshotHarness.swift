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
/// - `TRANSLATOR_DEBUG_SNAPSHOT_SCENES` — any of `popup,settings,history,probes` (default all).
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
        let raw = environment["TRANSLATOR_DEBUG_SNAPSHOT_SCENES"] ?? "popup,settings,history,probes"
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
        for (index, text) in texts.enumerated() {
            let slug = Self.slug(text)
            delegate.snapshotPresent(text: text)
            // The first frame, before any answer: what the user sees while waiting.
            if index == 0 {
                try? await Task.sleep(for: .milliseconds(16))
                await capturePopup("popup-\(index)-\(slug)-loading-\(appearance)", settle: false)
            }
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
        // The announcement path: a bare message, no lookup behind it.
        delegate.snapshotAnnounce("No text selected.", level: .info)
        try? await Task.sleep(for: .milliseconds(400))
        await capturePopup("popup-announce-\(appearance)")
        delegate.snapshotHidePopup()
        backdrop.close()
        try? await Task.sleep(for: .milliseconds(300))
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

    private func historyScene(appearance: String) async {
        guard let delegate else { return }
        delegate.showHistory()
        try? await Task.sleep(for: .seconds(2))
        guard let window = delegate.snapshotWindow(id: "history") else { return }
        write(window, "history-\(appearance)")
        window.close()
        try? await Task.sleep(for: .milliseconds(300))
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
        backdrop.write(panel: window, to: output.appendingPathComponent("\(name).png"))
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
            return (panel.isVisible, "visible=\(panel.isVisible) isKeyWindow=\(panel.isKeyWindow)")
        }

        // The announcement path closes itself (info: 2.5 s) and ends no session.
        delegate.snapshotHidePopup()
        let sessions = popup.sessionsEnded
        delegate.snapshotAnnounce("No text selected.", level: .info)
        try? await Task.sleep(for: .milliseconds(3200))
        let visible = delegate.snapshotPopupWindow?.isVisible ?? false
        let ended = popup.sessionsEnded - sessions
        let passed = !visible && popup.lastHideReason == .announcementEnded && ended == 0
        NSLog("PROBE announcement-auto-hides \(passed ? "PASS" : "FAIL") visible=\(visible) reason=\(Self.name(popup.lastHideReason)) closeSession=+\(ended)")
        delegate.snapshotHidePopup()
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
                continue
            }
            let (passed, result) = await check(panel)
            detail = "\(result) attempt=\(attempt)"
            if passed {
                NSLog("PROBE \(name) PASS \(detail)")
                return
            }
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

    @discardableResult
    func write(panel: NSWindow, to url: URL) -> Bool {
        guard let window, let capture = Self.capture else {
            NSLog("[snapshot] no composited capture for \(url.lastPathComponent); panel alone")
            return WindowSnapshot.write(panel, to: url)
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
              let image = capture(rect, array, 0)?.takeRetainedValue(),
              let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
        else {
            NSLog("[snapshot] could not capture \(url.lastPathComponent)")
            return false
        }
        do {
            try data.write(to: url)
            NSLog("[snapshot] wrote \(url.lastPathComponent) \(image.width)x\(image.height) panel \(Int(panel.frame.width))x\(Int(panel.frame.height))")
            return true
        } catch {
            NSLog("[snapshot] write failed: \(error)")
            return false
        }
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
