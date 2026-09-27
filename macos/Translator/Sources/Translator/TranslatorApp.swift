import AppKit
import SwiftUI
import TranslatorCore

@main
struct TranslatorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra("Translator", systemImage: "character.bubble") {
            MenuBarContent(model: delegate.model, delegate: delegate)
        }
        .menuBarExtraStyle(.menu)
        .commands { WindowCommands(delegate: delegate) }
    }
}

/// File > Close (⌘W) and Edit > Find (⌘F) for every window of the app.
///
/// SwiftUI's main menu for a menu bar app has Edit and Window menus but no File menu, so
/// ⌘W reached no window: Settings answered it with an override of its own, History and
/// Add to Anki beeped. One menu item is the Mac's way and covers every window. It is
/// declared here rather than added to `NSApp.mainMenu` by hand because SwiftUI rebuilds
/// that menu and drops what it did not make. The menu is never on screen (an accessory
/// app shows no menu bar of its own) but answers key equivalents while our window is key.
private struct WindowCommands: Commands {
    let delegate: AppDelegate

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Close") { NSApp.keyWindow?.performClose(nil) }
                .keyboardShortcut("w")
        }
        CommandGroup(after: .textEditing) {
            // The key window's toolbar search field (History's), as ⌘F does in any Mac
            // window with one; nothing elsewhere.
            Button("Find…") { delegate.focusSearch(nil) }
                .keyboardShortcut("f")
        }
    }
}

private struct MenuBarContent: View {
    @Bindable var model: AppModel
    let delegate: AppDelegate

    var body: some View {
        Text(model.connectionSummary)
        Divider()
        translateItem
        // A verb, and no ellipsis: it opens a list and asks nothing.
        Button("Show History") { delegate.showHistory() }
        Divider()
        // An accessory app never shows its app menu, so About has to live here.
        Button("About Translator") {
            NSApp.activate()
            NSApp.orderFrontStandardAboutPanel(nil)
        }
        Button("Settings…") { delegate.showSettings() }
            .keyboardShortcut(",")
        Divider()
        Button("Quit Translator") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }

    /// The global shortcut in the menu's own shortcut column, where the menu can express
    /// it; a key it cannot (a function key) goes after the title instead.
    @ViewBuilder
    private var translateItem: some View {
        let action = { delegate.translateSelection() }
        if let combo = model.hotKey, let shortcut = combo.menuShortcut {
            Button("Translate Selection", action: action)
                .keyboardShortcut(shortcut)
        } else if let combo = model.hotKey {
            Button("Translate Selection \(combo.displayString)", action: action)
        } else {
            Button("Translate Selection", action: action)
        }
    }
}

private extension KeyCombo {
    /// The same combination as a SwiftUI shortcut, when the key has an equivalent there.
    var menuShortcut: KeyboardShortcut? {
        let key: KeyEquivalent
        switch keyCode {
        case 36: key = .return
        case 48: key = .tab
        case 49: key = .space
        case 51: key = .delete
        case 53: key = .escape
        case 117: key = .deleteForward
        case 115: key = .home
        case 119: key = .end
        case 116: key = .pageUp
        case 121: key = .pageDown
        case 123: key = .leftArrow
        case 124: key = .rightArrow
        case 125: key = .downArrow
        case 126: key = .upArrow
        default:
            let name = KeyCombo.keyName(for: keyCode)
            guard name.count == 1, let character = name.lowercased().first else { return nil }
            key = KeyEquivalent(character)
        }
        var flags: EventModifiers = []
        if modifiers & KeyCombo.commandMask != 0 { flags.insert(.command) }
        if modifiers & KeyCombo.optionMask != 0 { flags.insert(.option) }
        if modifiers & KeyCombo.controlMask != 0 { flags.insert(.control) }
        if modifiers & KeyCombo.shiftMask != 0 { flags.insert(.shift) }
        return KeyboardShortcut(key, modifiers: flags)
    }
}

/// Owns everything AppKit: hot key, Services entry, the floating popup, auxiliary windows.
///
/// Windows are plain `NSWindow`s hosting SwiftUI rather than SwiftUI `Window` scenes,
/// because an accessory (menu-bar) app opens them from AppKit callbacks — a hot key, a
/// Services invocation — where SwiftUI's `openWindow` action is not reachable.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model: AppModel
    private let client: IPCClient
    private let hotKeys = HotKeyManager()
    private var announceDismissal: Task<Void, Never>?
    private lazy var popup = PopupPanelController(model: model)
    private var windows: [String: NSWindow] = [:]
    /// Dialogs that follow their content's size (see `present(id:…)`).
    private var contentSizeObservers: [String: NSKeyValueObservation] = [:]
    /// Windows whose content is rebuilt on every open drop it on close; History tells the
    /// model it is no longer on screen.
    private var closeObservers: [String: NSObjectProtocol] = [:]

    override init() {
        let client = IPCClient(socketPath: IPCClient.defaultSocketPath())
        self.client = client
        self.model = AppModel(client: client)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)   // menu-bar app: no Dock icon
        // Snapshot runs must not claim the hot key or the Services entry: the installed
        // app may be running beside them, and a clash would put a banner in every image.
        if let dir = ProcessInfo.processInfo.environment["TRANSLATOR_DEBUG_SNAPSHOT"], !dir.isEmpty {
            model.start()
            SnapshotRunner(delegate: self, output: URL(fileURLWithPath: dir)).run()
            return
        }
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()

        model.loadStoredHotKey()
        // Know our own permission state from the start: the setup stages read it, and it
        // is recorded where the installer report can see it.
        model.refreshAccessibilityTrust()
        applyHotKey(model.hotKey)
        openSetupIfUnfinished()
        model.start()
        openDebugTargets()
    }

    /// Development hooks, so the UI can be driven without a real selection:
    /// `TRANSLATOR_DEBUG_TEXT` opens the popup on that text, `TRANSLATOR_DEBUG_WINDOW`
    /// (`settings` | `history` | `anki`) opens one auxiliary window,
    /// `TRANSLATOR_DEBUG_CAPTURE` runs the real capture path.
    private func openDebugTargets() {
        let environment = ProcessInfo.processInfo.environment
        if let text = environment["TRANSLATOR_DEBUG_TEXT"], !text.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.present(text: text)
            }
        }
        // The capture path is the only one that raises the Accessibility request, and it
        // normally needs a hot key press. Without this hook the grant cannot be asked for
        // from a launch, which is exactly what an unattended check has to do.
        if environment["TRANSLATOR_DEBUG_CAPTURE"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.translateSelection()
            }
        }
        // Registering as a login item is a one-press action in Settings, and an
        // unattended check has no way to press it. Same reason as the capture hook.
        if let wanted = environment["TRANSLATOR_DEBUG_LOGIN"] {
            NSLog("[translator] login item before: \(LoginItem.state)")
            switch wanted {
            case "register":
                do { try LoginItem.enable() } catch { NSLog("[translator] register failed: \(error)") }
            case "unregister":
                do { try LoginItem.disable() } catch { NSLog("[translator] unregister failed: \(error)") }
            default: break
            }
            NSLog("[translator] login item after: \(LoginItem.state)")
            NSLog("[translator] bundle: \(Bundle.main.bundleURL.path)")
        }
        switch environment["TRANSLATOR_DEBUG_WINDOW"] {
        case "settings": DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.showSettings() }
        case "history": DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in self?.showHistory() }
        case "anki": DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in self?.showAnkiSheet() }
        default: break
        }
    }

    /// Edit > Find (see `WindowCommands`): the key window's toolbar search field, as ⌘F
    /// does in any Mac window with one.
    @objc func focusSearch(_ sender: Any?) {
        searchItem(in: NSApp.keyWindow)?.beginSearchInteraction()
    }

    private func searchItem(in window: NSWindow?) -> NSSearchToolbarItem? {
        window?.toolbar?.items.lazy.compactMap { $0 as? NSSearchToolbarItem }.first
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeys.unregister()
        model.stop()
    }

    // MARK: - Hot key & selection

    /// Registers the shortcut, or with nil (the user cleared it) registers none.
    func applyHotKey(_ combo: KeyCombo?) {
        // Snapshot runs must not claim a combination on the user's Mac; the harness
        // records what would have been registered instead.
        if let snapshotHotKeys {
            snapshotHotKeys(combo)
            return
        }
        guard let combo else {
            hotKeys.unregister()
            model.shortcutRegistered = false
            return
        }
        let registered = hotKeys.register(combo) { [weak self] in
            MainActor.assumeIsolated { self?.translateSelection() }
        }
        model.shortcutRegistered = registered
        if !registered {
            announce("\(combo.displayString) is already taken by another app.", level: .warning)
        }
    }

    func translateSelection() {
        translateSelection(capture: SelectionCapture.currentSelection)
    }

    /// The hot key's work, with the capture passed in so the snapshot probes can press
    /// the key without reading (or copying from) the user's real selection.
    ///
    /// A press while the panel has keyboard focus closes it, as a second press closes
    /// Maccy. It must not capture: the panel is key, so the ⌘C fallback would copy from
    /// the panel itself, find nothing, and replace the card with "No text selected."
    private func translateSelection(capture: () -> String?, refreshTrust: Bool = true) {
        if popup.isVisible, popup.isKey {
            popup.dismiss()
            return
        }
        if refreshTrust { model.refreshAccessibilityTrust() }
        guard let text = capture(), !text.isEmpty else {
            if model.accessibilityTrusted {
                announce("No text selected.", level: .info)
            } else {
                SelectionCapture.requestTrust()
                // The Setup checklist on General says what is missing and has the button;
                // a popup banner raised here was never on screen.
                showSettings(pane: .general)
            }
            return
        }
        present(text: text)
    }

    /// Show Settings on a launch where setup is not finished.
    ///
    /// A menu bar app with nothing on screen gives a new user nowhere to start, and the
    /// steps that make it work — a permission, a language pair, Anki — are all in
    /// Settings. Once the required steps are done it stops appearing, so it never
    /// becomes a nag; the flag remembers that across launches.
    private func openSetupIfUnfinished() {
        guard !UserDefaults.standard.bool(forKey: Self.setupSeenKey) else { return }
        Task { @MainActor in
            // Give the backend its retry burst, so the stages show real state and not
            // "unknown" for everything.
            try? await Task.sleep(for: .seconds(2))
            model.refreshAccessibilityTrust()
            model.refreshLoginItem()
            await model.refreshAll()
            if model.setupPlan.isReady {
                UserDefaults.standard.set(true, forKey: Self.setupSeenKey)
            } else {
                // The checklist is on the General pane.
                showSettings(pane: .general)
            }
        }
    }

    static let setupSeenKey = "setupCompleted"

    /// Say something to the user when there is no popup on screen to say it in.
    ///
    /// Banners render inside the popup, so raising one from the hot key — nothing
    /// selected, or a combination another app already owns — used to set state that
    /// nobody displayed: the key did nothing and said nothing. The panel comes up with
    /// the message and closes itself, since there is no translation to keep it open for.
    ///
    /// It never takes keyboard focus: the user is typing somewhere, and a message must not
    /// swallow the next keystrokes. A click anywhere or its timer closes it.
    ///
    /// The message is the panel's own, not the model's: the lookup and its error stay as
    /// they are underneath. Add to Anki reads that lookup, and wiping it for a message
    /// would close the window and lose the user's choices in it.
    private func announce(_ message: String, level: NotificationLevel, at pointer: CGPoint? = nil) {
        let duration: Duration = level == .info ? .seconds(2.5) : .seconds(4)
        model.speak(message)
        showPopup(
            width: PopupLayout.announcementWidth, at: pointer,
            announcement: AppModel.BannerMessage(text: message, level: level)
        )
        announceDismissal?.cancel()
        announceDismissal = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.popup.hide(reason: .announcementEnded) }
        }
    }

    /// Services entry point (declared as `NSServices` in Info.plist): zero permissions.
    @objc func translateSelection(
        _ pasteboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString>?
    ) {
        guard let text = pasteboard.string(forType: .string), !text.isEmpty else {
            error?.pointee = "No text to translate." as NSString
            return
        }
        present(text: text)
    }

    private func present(text: String, at pointer: CGPoint? = nil) {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        announceDismissal?.cancel()
        // The panel draws its first frame from the state it is shown with, so the query
        // is in the state before it appears: the headword is there from the first frame,
        // never the previous lookup. `translate` sets the same state and goes on from it.
        model.lastError = nil
        model.banner = nil
        model.state = ViewState(original: query, originalRaw: text, loading: true)
        showPopup(width: PopupLayout.width(forQuery: query), at: pointer)
        Task { await model.translate(text) }
    }

    private func showPopup(width: CGFloat, at pointer: CGPoint? = nil, announcement: AppModel.BannerMessage? = nil) {
        // A lookup replaces an announcement: its timer must not hide the card.
        if announcement == nil { announceDismissal?.cancel() }
        popup.show(
            width: width,
            at: pointer ?? NSEvent.mouseLocation,
            announcement: announcement,
            openAnki: { [weak self] in self?.showAnkiSheet() },
            onDismiss: { [weak self] in Task { await self?.model.closeSession() } }
        )
    }

    // MARK: - Windows

    func showHistory() {
        let reopening = windows["history"] != nil
        present(
            id: "history",
            title: "History",
            size: HistoryView.defaultSize,
            chrome: .document(autosaveName: "History", searchInToolbar: true),
            onReopen: .keepContent,
            view: HistoryView(
                model: model,
                onOpen: { [weak self] entryId in self?.showHistoryEntry(entryId) },
                scrollToTop: { [weak self] in self?.scrollHistoryToTop() }
            )
        )
        // While it is on screen the list follows new lookups (see `AppModel.lookupSettled`).
        model.historyWindowOpen = true
        if closeObservers["history"] == nil, let window = windows["history"] {
            closeObservers["history"] = NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification, object: window, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.model.historyWindowOpen = false }
            }
        }
        // The view is kept between opens, so its first-load task does not run again. The
        // count goes up once the list holds the new rows, which is when the view can put
        // the newest one at the top.
        if reopening {
            Task {
                await model.loadHistory()
                model.historyReopens += 1
            }
        }
    }

    /// Scrolls History's list to its top edge once the rows the reload just brought in are
    /// laid out (the list moves itself when they are inserted, so this waits for that).
    private func scrollHistoryToTop() {
        DispatchQueue.main.async { [weak self] in
            guard let root = self?.windows["history"]?.contentView else { return }
            var stack = [root]
            while let view = stack.popLast() {
                if let table = view as? NSTableView, let scroll = table.enclosingScrollView {
                    let clip = scroll.contentView
                    clip.scroll(to: NSPoint(x: clip.bounds.origin.x, y: -scroll.contentInsets.top))
                    scroll.reflectScrolledClipView(clip)
                    return
                }
                stack.append(contentsOf: view.subviews)
            }
        }
    }

    /// Shows Settings on `pane`, or on the pane it was left on when nil. The window and
    /// its panes are made once and kept, like any Mac settings window.
    func showSettings(pane: SettingsPaneID? = nil) {
        settingsWindow.show(pane: pane)
    }

    private lazy var settingsWindow = SettingsWindowController(
        model: model,
        applyHotKey: { [weak self] combo in self?.applyHotKey(combo) },
        // A recorder listening for a combination must hear it, not have the registered
        // shortcut fire a lookup instead.
        suspendHotKey: { [weak self] suspended in
            guard let self else { return }
            if let snapshotHotKeys {
                if suspended { snapshotHotKeys(nil) } else { applyHotKey(model.hotKey) }
                return
            }
            if suspended { hotKeys.unregister() } else { applyHotKey(model.hotKey) }
        }
    )

    func showAnkiSheet() {
        present(
            id: "anki",
            title: "Add to Anki",
            size: AnkiUpsertSheet.initialSize,
            chrome: .dialog,
            // Every open is a new note: fresh choices, a fresh preview.
            onReopen: .rebuildContent,
            view: AnkiUpsertSheet(
                model: model,
                openSettings: { [weak self] in self?.showSettings(pane: .anki) },
                onFinished: { [weak self] added in
                    self?.close(id: "anki")
                    if added { self?.reshowPopupWithOutcome() }
                }
            )
        )
    }

    /// The panel stepped aside for Add to Anki; bring it back where it was, over the card
    /// that was just added, so the confirmation banner has somewhere to appear.
    private func reshowPopupWithOutcome() {
        guard !model.state.originalText.isEmpty else { return }
        showPopup(width: PopupLayout.width(forQuery: model.state.originalText), at: popup.lastTopLeft)
    }

    func showHistoryEntry(_ entryId: Int) {
        announceDismissal?.cancel()
        let text = model.history.first { $0.entryId == entryId }?.text ?? ""
        let pointer = NSEvent.mouseLocation
        // The entry comes from the local history, so it is quick: show the panel once the
        // state holds it, not over the previous lookup. When the backend refuses, the
        // state still holds the previous lookup, so there is nothing to show; the History
        // window says why.
        Task {
            guard await model.selectHistory(entryId) else { return }
            // As for a new lookup: nothing said about the previous one carries over.
            model.lastError = nil
            model.banner = nil
            showPopup(width: PopupLayout.width(forQuery: text.isEmpty ? model.state.originalText : text), at: pointer)
        }
    }

    /// How one of the app's standard windows is framed.
    struct WindowChrome {
        var styleMask: NSWindow.StyleMask
        /// Remembers the frame between launches; nil centres the window on first open.
        var autosaveName: String?
        /// Bridge `.searchable` / `.toolbar` from the SwiftUI view into the window's toolbar.
        var searchInToolbar = false
        /// The window takes the content's own size and the user cannot resize it.
        var fitsContent = false

        /// A resizable document-style window, such as History.
        static func document(autosaveName: String? = nil, searchInToolbar: Bool = false) -> WindowChrome {
            WindowChrome(
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                autosaveName: autosaveName,
                searchInToolbar: searchInToolbar
            )
        }

        /// A fixed-size dialog sized by its content: Add to Anki.
        static let dialog = WindowChrome(styleMask: [.titled, .closable], fitsContent: true)
    }

    /// What reopening a window does to the view inside it. The window itself — frame,
    /// position, controller — is always kept.
    enum ReopenBehaviour {
        /// Same view, same state (selection, search, scroll position).
        case keepContent
        /// A new view identity, so its state resets and its `.task` runs again.
        case rebuildContent
    }

    /// Shows one of the app's own windows, creating it on first use and reusing it after.
    ///
    /// The windows are standard titled windows with an opaque title bar: content never runs
    /// under the traffic lights, and toolbars get their look from the system.
    private func present(
        id: String,
        title: String,
        size: CGSize,
        chrome: WindowChrome = .document(),
        onReopen: ReopenBehaviour = .rebuildContent,
        view: some View
    ) {
        NSApp.activate()
        if let window = windows[id] {
            if onReopen == .rebuildContent, let host = window.contentViewController as? NSHostingController<AnyView> {
                host.rootView = AnyView(view.id(UUID()))
            }
            window.makeKeyAndOrderFront(nil)
            return
        }
        let controller = NSHostingController(rootView: AnyView(view))
        // One owner of the size. A resizable window only takes its minimum from the
        // content and is otherwise the user's to size. A dialog follows its content, but
        // through `preferredContentSize` applied here rather than through constraints:
        // AppKit would keep the bottom edge and push the title bar up as it grows.
        controller.sizingOptions = chrome.fitsContent ? [.preferredContentSize] : [.minSize]
        if chrome.searchInToolbar { controller.sceneBridgingOptions = [.toolbars] }

        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: size),
            styleMask: chrome.styleMask,
            backing: .buffered,
            defer: false
        )
        window.contentViewController = controller
        window.title = title
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        if chrome.searchInToolbar { window.toolbarStyle = .unified }
        if chrome.fitsContent {
            let fitting = controller.view.fittingSize
            window.setContentSize(fitting.width > 0 && fitting.height > 0 ? fitting : size)
            contentSizeObservers[id] = controller.observe(\.preferredContentSize) { [weak window] controller, _ in
                MainActor.assumeIsolated {
                    window?.fitContent(to: controller.preferredContentSize)
                }
            }
        } else {
            window.setContentSize(size)
        }
        if onReopen == .rebuildContent {
            // A closed window is only ordered out, and a view left in it would go on
            // reacting to the model: Add to Anki preparing notes nobody sees. Its content
            // goes with the window; the next open builds it again anyway.
            closeObservers[id] = NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification, object: window, queue: .main
            ) { [weak controller] _ in
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        guard let controller, controller.view.window?.isVisible != true else { return }
                        controller.rootView = AnyView(EmptyView())
                    }
                }
            }
        }
        window.center()
        if let name = chrome.autosaveName {
            window.setFrameUsingName(name)
            window.setFrameAutosaveName(name)
        }
        windows[id] = window
        window.makeKeyAndOrderFront(nil)
    }

    private func close(id: String) {
        windows[id]?.close()
    }

    // MARK: - Snapshot hooks (see SnapshotHarness.swift)

    /// Where snapshot scenes open the panel: a fixed point, so every image is framed alike.
    var snapshotPointer: CGPoint {
        let visible = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        return CGPoint(x: visible.minX + 160, y: visible.maxY - 40)
    }

    func snapshotPresent(text: String) { present(text: text, at: snapshotPointer) }
    func snapshotHidePopup() { popup.hide() }
    var snapshotPopupWindow: NSWindow? { popup.window }
    var snapshotPopup: PopupPanelController { popup }
    /// Show the panel again over whatever the model holds now, without a new lookup.
    func snapshotReshowPopup() {
        showPopup(width: PopupLayout.width(forQuery: model.state.originalText), at: snapshotPointer)
    }
    /// Show an announcement, as the hot key does when nothing is selected.
    func snapshotAnnounce(_ message: String, level: NotificationLevel) {
        announce(message, level: level, at: snapshotPointer)
    }
    /// Press the hot key with `capture` standing in for the selection: the probes must
    /// neither read the user's selection nor post ⌘C into the user's apps.
    func snapshotHotKeyPress(capture: () -> String?) {
        translateSelection(capture: capture, refreshTrust: false)
    }
    func snapshotWindow(id: String) -> NSWindow? { windows[id] }
    /// The Settings window's controller (made on first use): its window, and pane selection.
    var snapshotSettingsWindow: SettingsWindowController { settingsWindow }
    /// Set by the harness: every registration the app would make (nil: none) goes here
    /// instead of to Carbon, so a probe can see them and the user's Mac is left alone.
    var snapshotHotKeys: ((KeyCombo?) -> Void)?
}

extension NSWindow {
    /// Resizes the window to hold `size` of content with its title bar where it is, moving
    /// up only as far as needed to stay above the bottom of the screen.
    func fitContent(to size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let content = contentRect(forFrameRect: frame)
        guard abs(content.width - size.width) >= 0.5 || abs(content.height - size.height) >= 0.5 else { return }
        var target = frameRect(forContentRect: CGRect(origin: content.origin, size: size))
        target.origin.y = frame.maxY - target.height
        if let visible = screen?.visibleFrame {
            target.origin.y = max(target.origin.y, visible.minY)
            target.origin.y = min(target.origin.y, visible.maxY - target.height)
        }
        setFrame(target, display: true)
    }
}
