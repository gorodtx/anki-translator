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
    }
}

private struct MenuBarContent: View {
    @Bindable var model: AppModel
    let delegate: AppDelegate

    var body: some View {
        Text(model.connectionSummary)
        Divider()
        Button("Translate Selection  \(model.hotKey.displayString)") { delegate.translateSelection() }
        Button("History…") { delegate.showHistory() }
        Button("Settings…") { delegate.showSettings() }
        Divider()
        Button("Quit Translator") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
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
    private var stateObserver: Task<Void, Never>?

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
            observePopupResize()
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
        observePopupResize()
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

    func applicationWillTerminate(_ notification: Notification) {
        stateObserver?.cancel()
        hotKeys.unregister()
        model.stop()
    }

    // MARK: - Hot key & selection

    func applyHotKey(_ combo: KeyCombo) {
        let registered = hotKeys.register(combo) { [weak self] in
            MainActor.assumeIsolated { self?.translateSelection() }
        }
        model.shortcutRegistered = registered
        if !registered {
            announce("\(combo.displayString) is already taken by another app.", level: .warning)
        }
    }

    func translateSelection() {
        model.refreshAccessibilityTrust()
        guard let text = SelectionCapture.currentSelection(), !text.isEmpty else {
            if model.accessibilityTrusted {
                announce("No text selected.", level: .info)
            } else {
                SelectionCapture.requestTrust()
                showSettings()
                model.show(banner: "Grant Accessibility to read the selection.", level: .warning)
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
            await model.refreshAll()
            let plan = SetupPlanner.plan(
                connected: model.isConnected,
                ping: model.ping,
                accessibilityTrusted: model.accessibilityTrusted,
                shortcutRegistered: model.shortcutRegistered,
                shortcut: model.hotKey.displayString,
            loginItem: LoginItem.state,
                anki: model.ankiStatus
            )
            if plan.isReady {
                UserDefaults.standard.set(true, forKey: Self.setupSeenKey)
            } else {
                showSettings()
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
    private func announce(_ message: String, level: NotificationLevel) {
        model.clearForAnnouncement()
        showPopup()
        model.show(banner: message, level: level)
        announceDismissal?.cancel()
        announceDismissal = Task { [weak self] in
            try? await Task.sleep(for: .seconds(level == .info ? 2.5 : 4))
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.popup.hide() }
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

    private func present(text: String) {
        showPopup()
        Task { await model.translate(text) }
    }

    private func showPopup() {
        popup.show(
            at: NSEvent.mouseLocation,
            openAnki: { [weak self] in self?.showAnkiSheet() },
            onClose: { [weak self] in Task { await self?.model.closeSession() } }
        )
    }

    /// Keep the panel fitted while partial → final content grows.
    private func observePopupResize() {
        stateObserver = Task { [weak self] in
            var lastState: ViewState?
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(120))
                guard let self else { return }
                if self.model.state != lastState {
                    lastState = self.model.state
                    self.popup.resizeToContent()
                }
            }
        }
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
            view: HistoryView(model: model) { [weak self] entryId in self?.showHistoryEntry(entryId) }
        )
        // The view is kept between opens, so its first-load task does not run again.
        if reopening { Task { await model.loadHistory() } }
    }

    func showSettings() {
        present(
            id: "settings",
            title: "Translator Settings",
            size: CGSize(width: 520, height: 580),
            view: SettingsView(model: model) { [weak self] combo in self?.applyHotKey(combo) }
        )
    }

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
                openSettings: { [weak self] in self?.showSettings() },
                onFinished: { [weak self] _ in self?.close(id: "anki") }
            )
        )
    }

    func showHistoryEntry(_ entryId: Int) {
        showPopup()
        Task { await model.selectHistory(entryId) }
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

        /// A resizable document-style window: History, and Settings until it has its own.
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
        // One owner of the size: a dialog follows its content, a resizable window only
        // takes its minimum from the content and is otherwise the user's to size.
        controller.sizingOptions = chrome.fitsContent ? [.minSize, .intrinsicContentSize, .maxSize] : [.minSize]
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
        if !chrome.fitsContent { window.setContentSize(size) }
        if chrome.searchInToolbar { window.toolbarStyle = .unified }
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

    func snapshotPresent(text: String) { present(text: text) }
    func snapshotHidePopup() { popup.hide() }
    var snapshotPopupWindow: NSWindow? { popup.window }
    func snapshotWindow(id: String) -> NSWindow? { windows[id] }
}
