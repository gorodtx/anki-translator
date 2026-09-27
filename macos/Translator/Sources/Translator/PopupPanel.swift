import AppKit
import SwiftUI
import TranslatorCore

/// The floating panel that holds a translation, built the way Maccy builds its popup.
///
/// A borderless `NSPanel` never becomes key, so it never hears about an outside click and
/// never receives Esc. This one can become key without activating the app
/// (`.nonactivatingPanel` + `canBecomeKey`): the user's app stays frontmost with its
/// selection intact, while the panel gets keyboard focus and a `resignKey` when the user
/// clicks anywhere else.
final class TranslationPanel: NSPanel {
    /// Called after the panel lost key status.
    var onResignKey: (() -> Void)?
    /// Called for Esc, however it arrives.
    var onCancel: (() -> Void)?

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: PopupLayout.narrowWidth, height: 120),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        // A menu-like surface: above ordinary floating palettes, below the screen saver.
        level = .popUpMenu
        collectionBehavior = [.auxiliary, .stationary, .moveToActiveSpace, .fullScreenAuxiliary, .ignoresCycle]
        hidesOnDeactivate = false
        animationBehavior = .none
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        // Text is selectable everywhere, so a drag on text must select, not move the
        // window. The panel moves by its bare background instead (see the root view).
        isMovableByWindowBackground = false
        isReleasedWhenClosed = false
        becomesKeyOnlyIfNeeded = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func resignKey() {
        super.resignKey()
        onResignKey?()
    }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }

    /// Esc is taken before any view sees it: nothing in the panel has a use for it, and a
    /// selectable text view would otherwise swallow it.
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, event.keyCode == Self.escapeKeyCode {
            onCancel?()
            return
        }
        super.sendEvent(event)
    }

    static let escapeKeyCode: UInt16 = 53
}

/// Owns the translation panel: where it appears, how big it is, and when it goes away.
///
/// It is the only owner of the window size. The hosting view does not size the window
/// (`sizingOptions = []`); the SwiftUI content reports its natural height and this
/// controller applies it on the next run-loop turn. Two owners fighting over the frame is
/// what used to end in AppKit's "more Update Constraints in Window passes than there are
/// views" exception on a long sentence.
@MainActor
final class PopupPanelController: NSObject {
    private var panel: TranslationPanel?
    private var hosting: NSHostingView<TranslationPopupView>?
    private let model: AppModel

    private var onDismiss: (() -> Void)?
    private var openAnki: (() -> Void)?

    private var width: CGFloat = PopupLayout.narrowWidth
    private var naturalHeight: CGFloat = 0
    private var naturalHeightWidth: CGFloat = 0
    private var resizeScheduled = false
    /// The first height after showing is applied without animation: there is no open
    /// animation, so the panel must not visibly grow into its first size.
    private var sizedSinceShow = false

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var keyObserver: NSObjectProtocol?

    /// Snapshot capture runs: other apps (or sibling test runs) may take focus while a
    /// frame is captured, and that must not dismiss the panel mid-scene.
    var suspendsDismissal = false
    /// The last reason the panel went away, for the behaviour probes.
    private(set) var lastHideReason: PopupHideReason?
    /// How many times hiding ended the backend session (called `onDismiss`).
    private(set) var sessionsEnded = 0

    init(model: AppModel) {
        self.model = model
        super.init()
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    /// The window itself, for the snapshot harness.
    var window: NSWindow? { panel }

    /// Show the panel with its top-left corner at `pointer`.
    ///
    /// - Parameter width: decided by the caller from the query and kept for the lookup.
    func show(
        width: CGFloat,
        at pointer: CGPoint,
        openAnki: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.onDismiss = onDismiss
        self.openAnki = openAnki
        let panel = ensurePanel()
        self.width = width
        sizedSinceShow = false

        let visible = screen(containing: pointer).visibleFrame
        // Re-showing the same content knows its height already; anything else starts at
        // one header line and takes its real height on the next turn, before it is seen.
        let natural = naturalHeightWidth == width && naturalHeight > 0 ? naturalHeight : 48
        let height = PopupLayout.height(forNatural: natural, visibleHeight: visible.height)
        let frame = PopupLayout.frame(for: CGSize(width: width, height: height), pointer: pointer, visible: visible)
        panel.setFrame(frame, display: false)
        panel.orderFrontRegardless()
        panel.makeKey()
        installMonitors()
        scheduleResize()
    }

    /// Hide without ending the lookup (a new lookup, an announcement ending, the harness).
    func hide() {
        hide(reason: .programmatic)
    }

    func hide(reason: PopupHideReason) {
        guard let panel, panel.isVisible else { return }
        removeMonitors()
        lastHideReason = reason
        panel.orderOut(nil)
        if reason.endsSession {
            sessionsEnded += 1
            onDismiss?()
        }
    }

    /// The user dismissed the panel: Esc or a click outside it.
    func dismiss() {
        guard !suspendsDismissal else { return }
        hide(reason: .dismissed)
    }

    // MARK: - Size

    /// The content's natural height changed (reported by the root view's geometry).
    fileprivate func naturalHeightChanged(_ height: CGFloat) {
        naturalHeight = height
        naturalHeightWidth = width
        scheduleResize()
    }

    /// Frame changes wait for the next run-loop turn, so they never land inside the
    /// layout pass that reported them.
    private func scheduleResize() {
        guard !resizeScheduled else { return }
        resizeScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.resizeScheduled = false
            self.applyHeight()
        }
    }

    private func applyHeight() {
        guard let panel, panel.isVisible, naturalHeight > 0 else { return }
        let visible = (panel.screen ?? screen(containing: panel.frame.origin)).visibleFrame
        let height = PopupLayout.height(forNatural: naturalHeight, visibleHeight: visible.height)
        let target = PopupLayout.resized(panel.frame, toHeight: height, visible: visible)
        guard abs(target.height - panel.frame.height) > 0.5 || abs(target.minY - panel.frame.minY) > 0.5 else {
            sizedSinceShow = true
            return
        }
        if !sizedSinceShow || Motion.reduceMotion {
            sizedSinceShow = true
            panel.setFrame(target, display: true)
            return
        }
        // Maccy's verticallyResize: 0.2 s, top edge fixed.
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.allowsImplicitAnimation = false
            panel.animator().setFrame(target, display: true)
        }
    }

    // MARK: - Panel

    private func makeRootView() -> TranslationPopupView {
        TranslationPopupView(
            model: model,
            onNaturalHeight: { [weak self] height in self?.naturalHeightChanged(height) },
            onOpenAnki: { [weak self] in
                // Our own window is about to take focus: hide quietly, keep the session.
                self?.hide(reason: .ownWindowFocused)
                self?.openAnki?()
            }
        )
    }

    private func ensurePanel() -> TranslationPanel {
        if let panel { return panel }
        let panel = TranslationPanel()

        let hosting = NSHostingView(rootView: makeRootView())
        // One owner of the window size: this controller.
        hosting.sizingOptions = []
        hosting.autoresizingMask = [.width, .height]

        // The one glass surface of the panel; the content sits inside it, not beside it.
        let glass = NSGlassEffectView(frame: NSRect(origin: .zero, size: panel.frame.size))
        glass.style = .regular
        glass.cornerRadius = Self.cornerRadius
        glass.autoresizingMask = [.width, .height]
        hosting.frame = glass.bounds
        glass.contentView = hosting
        panel.contentView = glass

        panel.onResignKey = { [weak self] in self?.panelResignedKey() }
        panel.onCancel = { [weak self] in self?.dismiss() }
        self.panel = panel
        self.hosting = hosting
        return panel
    }

    static let cornerRadius: CGFloat = 12

    private func screen(containing point: CGPoint) -> NSScreen {
        NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens[0]
    }

    // MARK: - Dismissal

    /// Focus left the panel. Which window has it now decides what that means, and focus
    /// settles only after this call returns, so the decision waits one turn.
    private func panelResignedKey() {
        DispatchQueue.main.async { [weak self] in
            guard let self, let panel = self.panel, panel.isVisible else { return }
            let otherKey = NSApp.keyWindow.map { $0 !== panel } ?? false
            guard let reason = PopupFocusRule.reasonAfterResigningKey(
                panelStillKey: panel.isKeyWindow,
                newKeyWindowIsOurs: otherKey,
                dismissalSuspended: self.suspendsDismissal
            ) else { return }
            self.hide(reason: reason)
        }
    }

    /// Another of our windows became key: hide at once, and keep the session.
    private func ownWindowBecameKey(_ window: NSWindow) {
        guard let panel, panel.isVisible, window !== panel, !suspendsDismissal else { return }
        hide(reason: .ownWindowFocused)
    }

    /// A mouse-down anywhere outside this app. It covers clicks that change no key
    /// window: the menu bar, the Dock, a panel opened from Services that never got key.
    func outsideMouseDown() {
        guard isVisible else { return }
        dismiss()
    }

    private func installMonitors() {
        if globalMonitor == nil {
            globalMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.outsideMouseDown() }
            }
        }
        if localMonitor == nil {
            // Belt and braces for Esc: the panel's sendEvent sees it first when it is key.
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard event.keyCode == TranslationPanel.escapeKeyCode else { return event }
                let handled = MainActor.assumeIsolated { () -> Bool in
                    guard let self, self.isVisible else { return false }
                    self.dismiss()
                    return true
                }
                return handled ? nil : event
            }
        }
        if keyObserver == nil {
            keyObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main
            ) { [weak self] note in
                guard let window = note.object as? NSWindow else { return }
                MainActor.assumeIsolated { self?.ownWindowBecameKey(window) }
            }
        }
    }

    private func removeMonitors() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let keyObserver { NotificationCenter.default.removeObserver(keyObserver) }
        globalMonitor = nil
        localMonitor = nil
        keyObserver = nil
    }
}
