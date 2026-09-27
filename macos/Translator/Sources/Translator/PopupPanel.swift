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
    /// Offered every other key press first; true when it was handled.
    var onKeyDown: ((NSEvent) -> Bool)?

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: PopupLayout.narrowWidth, height: 120),
            styleMask: [.nonactivatingPanel],
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

    /// ⌘C copies selected text. An accessory app that is not active may have no Edit
    /// menu to turn the key into `copy:`, so the panel sends it down the responder chain.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if super.performKeyEquivalent(with: event) { return true }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags == .command, event.charactersIgnoringModifiers == "c" else { return false }
        return NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self)
    }

    /// Esc is taken before any view sees it: nothing in the panel has a use for it, and a
    /// selectable text view would otherwise swallow it.
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, event.keyCode == Self.escapeKeyCode {
            onCancel?()
            return
        }
        if event.type == .keyDown, onKeyDown?(event) == true { return }
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
    /// What the content needs to know about the frame it was given.
    private let chrome = PopupChrome()

    private var onDismiss: (() -> Void)?
    private var openAnki: (() -> Void)?

    private var width: CGFloat = PopupLayout.narrowWidth
    private var naturalHeight: CGFloat = 0
    private var naturalHeightWidth: CGFloat = 0
    private var heightReports = 0
    private var resizeScheduled = false
    /// The first height after showing is applied without animation: there is no open
    /// animation, so the panel must not visibly grow into its first size.
    private var sizedSinceShow = false
    /// A new lookup replaced the content of a panel already on screen: it keeps its
    /// height while loading instead of collapsing to one line and growing back.
    private var holdsHeightWhileLoading = false

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var keyObserver: NSObjectProtocol?
    private var monitorInstalls = 0
    /// The panel holds an announcement: it was shown without taking key, and going away
    /// ends no lookup.
    private(set) var showingAnnouncement = false

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
    /// The panel has keyboard focus (a lookup; an announcement never takes it).
    var isKey: Bool { panel?.isKeyWindow ?? false }

    /// What is listening for dismissal, for the behaviour probes. `installs` counts every
    /// monitor ever added, so a show that replaced one instead of keeping it shows up.
    struct MonitorState: Equatable, CustomStringConvertible {
        var global: Bool
        var local: Bool
        var observer: Bool
        var installs: Int
        var all: Bool { global && local && observer }
        var none: Bool { !global && !local && !observer }
        var description: String { "global=\(global) local=\(local) observer=\(observer) installs=\(installs)" }
    }

    var monitorState: MonitorState {
        MonitorState(
            global: globalMonitor != nil, local: localMonitor != nil, observer: keyObserver != nil,
            installs: monitorInstalls
        )
    }

    /// The last footer row the keyboard or a click activated, for the behaviour probes.
    private(set) var lastActivatedRow: PopupFooterRow?

    /// The window itself, for the snapshot harness.
    var window: NSWindow? { panel }

    /// Where the panel's top-left corner was when it was last shown.
    var lastTopLeft: CGPoint? {
        panel.map { CGPoint(x: $0.frame.minX, y: $0.frame.maxY) }
    }

    /// The footer row drawn highlighted, by the pointer or the arrow keys.
    var highlightedRow: PopupFooterRow? {
        get { chrome.highlightedRow }
        set { chrome.highlightedRow = newValue }
    }

    /// The announcement on screen; nil ends it (the panel then hides, see `hideIfEmpty`).
    var announcement: AppModel.BannerMessage? {
        get { chrome.announcement }
        set { chrome.announcement = newValue }
    }

    /// Show the panel with its top-left corner at `pointer`.
    ///
    /// - Parameters:
    ///   - width: decided by the caller from the query and kept for the lookup.
    ///   - announcement: shown instead of the lookup, which stays in the model untouched
    ///     (Add to Anki may be preparing a note from it). A lookup takes keyboard focus
    ///     (Esc, Return, the arrows); an announcement does not, so the keys the user is
    ///     typing stay in their app.
    func show(
        width: CGFloat,
        at pointer: CGPoint,
        announcement: AppModel.BannerMessage? = nil,
        openAnki: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.onDismiss = onDismiss
        self.openAnki = openAnki
        let takesKey = announcement == nil
        discardPanelIfAppearanceChanged()
        let panel = ensurePanel()
        // Only ordering out gives keyboard focus back to the user's app; its resignKey
        // belongs to the showing that ends here (see `panelResignedKey`).
        if !takesKey, panel.isKeyWindow { panel.orderOut(nil) }
        showingAnnouncement = !takesKey
        chrome.announcing = !takesKey
        chrome.announcement = announcement
        self.width = width
        sizedSinceShow = false
        holdsHeightWhileLoading = panel.isVisible
        chrome.showCount &+= 1
        // A new showing starts with no row highlighted.
        chrome.highlightedRow = nil

        let visible = screen(containing: pointer).visibleFrame
        // The previous lookup's height animation may still be running (a second lookup
        // within 0.2 s); left alone it lands on its own frame, the old width, after this
        // show. A zero-length animation of the frame replaces it.
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            panel.animator().setFrame(panel.frame, display: false)
        }
        // Size from the content as it is now. A hidden window keeps its last drawing, so
        // the content is laid out and drawn before the panel is ordered front: otherwise
        // the first frame on screen is the previous lookup. The content reports its
        // height during the layout the first frame change triggers, and the panel takes
        // that height before it is ever on screen.
        let reports = heightReports
        // Already on screen (a new lookup while open): no provisional height that could
        // reach the screen for a frame.
        let provisional = panel.isVisible ? panel.frame.height : Self.headerOnlyHeight
        panel.setFrame(frame(height: provisional, pointer: pointer, visible: visible), display: false)
        hosting?.layoutSubtreeIfNeeded()
        if heightReports != reports || naturalHeightWidth == width {
            panel.setFrame(frame(height: naturalHeight, pointer: pointer, visible: visible), display: false)
            hosting?.layoutSubtreeIfNeeded()
        }
        let scrolls = naturalHeightWidth == width && naturalHeight.rounded(.up) > panel.frame.height
        if chrome.bodyScrolls != scrolls {
            chrome.bodyScrolls = scrolls
            hosting?.layoutSubtreeIfNeeded()
        }
        panel.displayIfNeeded()
        // SwiftUI draws through layers, which reach the window server when the current
        // transaction commits; commit now, so ordering front cannot show the old tree.
        CATransaction.flush()
        panel.invalidateShadow()
        panel.orderFrontRegardless()
        if takesKey {
            panel.makeKey()
            // A text view the last lookup's selection left first responder would keep
            // the arrow keys from the footer.
            panel.makeFirstResponder(nil)
        }
        shownAppearance = Self.currentAppearance
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

    /// The user dismissed the panel: Esc, a click outside it, a second hot key press.
    /// An announcement has no lookup to end.
    func dismiss() {
        guard !suspendsDismissal else { return }
        hide(reason: showingAnnouncement ? .announcementEnded : .dismissed)
    }

    // MARK: - Size

    /// The content's natural height changed (reported by the root view's geometry).
    fileprivate func naturalHeightChanged(_ height: CGFloat) {
        naturalHeight = height
        naturalHeightWidth = width
        heightReports &+= 1
        scheduleResize()
        if height < 0.5 {
            DispatchQueue.main.async { [weak self] in self?.hideIfEmpty() }
        }
    }

    /// Nothing left to show — an announcement that ended before its panel — leaves no
    /// empty glass on screen.
    private func hideIfEmpty() {
        guard isVisible, naturalHeight < 0.5 else { return }
        let empty = showingAnnouncement
            ? chrome.announcement == nil
            : model.state.originalText.isEmpty && model.banner == nil
        guard empty else { return }
        hide(reason: .announcementEnded)
    }

    private func frame(height natural: CGFloat, pointer: CGPoint, visible: CGRect) -> CGRect {
        let height = PopupLayout.height(forNatural: natural, visibleHeight: visible.height)
        return PopupLayout.frame(for: CGSize(width: width, height: height), pointer: pointer, visible: visible)
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
        var height = PopupLayout.height(forNatural: naturalHeight, visibleHeight: visible.height)
        if holdsHeightWhileLoading {
            if model.state.loading {
                height = max(height, panel.frame.height)
            } else {
                holdsHeightWhileLoading = false
            }
        }
        // The width is the lookup's, whatever frame an earlier animation left behind.
        var current = panel.frame
        current.size.width = width
        let target = PopupLayout.resized(current, toHeight: height, visible: visible)
        let scrolls = naturalHeight.rounded(.up) > height
        if chrome.bodyScrolls != scrolls { chrome.bodyScrolls = scrolls }
        guard abs(target.height - panel.frame.height) > 0.5 || abs(target.minY - panel.frame.minY) > 0.5
            || abs(target.width - panel.frame.width) > 0.5
        else {
            sizedSinceShow = true
            return
        }
        if !sizedSinceShow || Motion.reduceMotion {
            sizedSinceShow = true
            panel.setFrame(target, display: true)
            panel.invalidateShadow()
            return
        }
        // Maccy's verticallyResize: 0.2 s, top edge fixed.
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.allowsImplicitAnimation = false
            panel.animator().setFrame(target, display: true)
        } completionHandler: { [weak self, weak panel] in
            // A clear window's shadow follows its drawn shape only when told to.
            panel?.invalidateShadow()
            // A new lookup may have started while this ran; fit its frame.
            MainActor.assumeIsolated {
                if let self, let panel, abs(panel.frame.width - self.width) > 0.5 { self.scheduleResize() }
            }
        }
    }

    // MARK: - Panel

    private func makeRootView() -> TranslationPopupView {
        TranslationPopupView(
            model: model,
            chrome: chrome,
            onNaturalHeight: { [weak self] height in self?.naturalHeightChanged(height) },
            onActivate: { [weak self] row in self?.perform(row) }
        )
    }

    // MARK: - Footer and keyboard

    /// Runs a footer row, whether it was clicked, chosen with Return, or its shortcut.
    private func perform(_ row: PopupFooterRow) {
        lastActivatedRow = row
        switch row {
        case .addToAnki:
            // Our own window is about to take focus: hide quietly, keep the session.
            hide(reason: .ownWindowFocused)
            openAnki?()
        case .copyTranslation:
            guard model.state.hasTranslation else { return }
            SelectionCapture.writeToPasteboard(model.state.translationText)
            model.show(banner: "Translation copied.", level: .success)
        case .newExamples:
            Task { await model.refreshExamples() }
        }
    }

    private var footerRows: PopupFooterNavigation.Rows {
        PopupFooter.rows(for: model).map { ($0.row, $0.enabled) }
    }

    /// Keys the panel handles itself, since nothing inside it takes keyboard focus:
    /// Page Up/Down, Space, Home/End scroll a capped body; ↑/↓ move through the footer
    /// rows as through a menu (or scroll, when there is no footer); Return activates the
    /// highlighted row, or Add to Anki… when none is.
    private func handleKeyDown(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        switch event.keyCode {
        case KeyCode.pageDown where flags.isEmpty: return scrollBody(.page(1))
        case KeyCode.pageUp where flags.isEmpty: return scrollBody(.page(-1))
        case KeyCode.home where flags.isEmpty: return scrollBody(.top)
        case KeyCode.end where flags.isEmpty: return scrollBody(.bottom)
        case KeyCode.space where flags.isEmpty || flags == .shift:
            return scrollBody(.page(flags == .shift ? -1 : 1))
        case KeyCode.downArrow where flags.isEmpty, KeyCode.upArrow where flags.isEmpty:
            let step = event.keyCode == KeyCode.downArrow ? 1 : -1
            // A text selection in progress keeps the arrows for itself.
            if textHasFocus { return false }
            let rows = footerRows
            if rows.contains(where: \.enabled) {
                chrome.highlightedRow = PopupFooterNavigation.move(from: chrome.highlightedRow, step: step, rows: rows)
                return true
            }
            return scrollBody(.line(step))
        case KeyCode.returnKey where flags.isEmpty, KeyCode.enter where flags.isEmpty:
            guard let row = PopupFooterNavigation.activation(highlighted: chrome.highlightedRow, rows: footerRows)
            else { return false }
            perform(row)
            return true
        default:
            return false
        }
    }

    /// Whether a text view holds the keyboard (the user is selecting text).
    private var textHasFocus: Bool {
        guard let responder = panel?.firstResponder, responder !== panel else { return false }
        return responder is NSText
    }

    private enum BodyScroll {
        case page(Int)
        case line(Int)
        case top
        case bottom
    }

    /// Scrolls the body the way a key scrolls any Mac scroll view. False when the body
    /// is not capped, so there is nothing to scroll.
    private func scrollBody(_ how: BodyScroll) -> Bool {
        guard chrome.bodyScrolls, let scroll = bodyScrollView, let document = scroll.documentView else { return false }
        let clip = scroll.contentView
        let visible = clip.bounds.height
        // Offsets from the top of the content, whichever way the document is flipped.
        let lowest = -clip.contentInsets.top
        let highest = max(lowest, document.frame.height - visible + clip.contentInsets.bottom)
        var offset = document.isFlipped ? clip.bounds.minY : highest - (clip.bounds.minY - lowest)
        switch how {
        case let .page(direction): offset += CGFloat(direction) * max(visible - Self.lineScroll, Self.lineScroll)
        case let .line(direction): offset += CGFloat(direction) * Self.lineScroll
        case .top: offset = lowest
        case .bottom: offset = highest
        }
        offset = min(max(offset, lowest), highest)
        let y = document.isFlipped ? offset : highest - (offset - lowest)
        clip.scroll(to: NSPoint(x: clip.bounds.minX, y: y))
        scroll.reflectScrolledClipView(clip)
        return true
    }

    private static let lineScroll: CGFloat = 32

    /// The body's scroll view: the one with the tallest document in the panel.
    var bodyScrollView: NSScrollView? {
        var best: NSScrollView?
        var stack = [panel?.contentView].compactMap { $0 }
        while let next = stack.popLast() {
            if let scroll = next as? NSScrollView,
               (scroll.documentView?.frame.height ?? 0) > (best?.documentView?.frame.height ?? 0) {
                best = scroll
            }
            stack.append(contentsOf: next.subviews)
        }
        return best
    }

    /// Whether the body is capped and scrolls, for the behaviour probes.
    var bodyScrolls: Bool { chrome.bodyScrolls }

    private enum KeyCode {
        static let returnKey: UInt16 = 36
        static let enter: UInt16 = 76
        static let space: UInt16 = 49
        static let pageUp: UInt16 = 116
        static let pageDown: UInt16 = 121
        static let home: UInt16 = 115
        static let end: UInt16 = 119
        static let downArrow: UInt16 = 125
        static let upArrow: UInt16 = 126
    }

    /// A hidden window does not redraw, and after a switch between light and dark it
    /// shows its old surface for a good part of a second once ordered front. A new window
    /// draws correctly from its first frame, so the panel is rebuilt instead.
    private func discardPanelIfAppearanceChanged() {
        guard let panel, !panel.isVisible, let shownAppearance, shownAppearance != Self.currentAppearance else { return }
        panel.onResignKey = nil
        panel.onCancel = nil
        panel.onKeyDown = nil
        panel.close()
        self.panel = nil
        hosting = nil
        naturalHeightWidth = 0
    }

    private var shownAppearance: NSAppearance.Name?

    private static var currentAppearance: NSAppearance.Name? {
        // An appearance set on the app applies at once; the effective one follows later.
        (NSApp.appearance ?? NSApp.effectiveAppearance).bestMatch(from: [
            .aqua, .darkAqua, .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua,
        ])
    }

    private func ensurePanel() -> TranslationPanel {
        if let panel { return panel }
        let panel = TranslationPanel()

        let hosting = NSHostingView(rootView: makeRootView())
        // One owner of the window size: this controller.
        hosting.sizingOptions = []
        hosting.autoresizingMask = [.width, .height]

        // The one glass surface of the panel, with the content above it as a sibling —
        // Maccy's ZStack order. Not as the glass's `contentView`: there, selectable text
        // loses its hierarchy and `.secondary` and `.tertiary` draw exactly like
        // `.primary`.
        let bounds = NSRect(origin: .zero, size: panel.frame.size)
        let container = NSView(frame: bounds)
        container.autoresizingMask = [.width, .height]
        let glass = NSGlassEffectView(frame: bounds)
        glass.style = .regular
        glass.cornerRadius = Self.cornerRadius
        glass.autoresizingMask = [.width, .height]
        hosting.frame = bounds
        container.addSubview(glass)
        container.addSubview(hosting, positioned: .above, relativeTo: glass)
        panel.contentView = container
        // The window server takes the window's shape — and so its shadow and edge — from
        // the root layer; without a corner radius there it draws a square shadow edge
        // around the rounded glass.
        for view in [container, container.superview].compactMap({ $0 }) {
            view.wantsLayer = true
            view.layer?.cornerRadius = Self.cornerRadius
            view.layer?.cornerCurve = .continuous
            view.layer?.masksToBounds = true
        }

        panel.onResignKey = { [weak self] in self?.panelResignedKey() }
        panel.onCancel = { [weak self] in self?.dismiss() }
        panel.onKeyDown = { [weak self] event in self?.handleKeyDown(event) ?? false }
        self.panel = panel
        self.hosting = hosting
        return panel
    }

    static let cornerRadius: CGFloat = 12
    /// A one-line headword with its paddings: the loading state, the usual first frame.
    static let headerOnlyHeight: CGFloat = 41

    private func screen(containing point: CGPoint) -> NSScreen {
        NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens[0]
    }

    // MARK: - Dismissal

    /// Focus left the panel. Which window has it now decides what that means, and focus
    /// settles only after this call returns, so the decision waits one turn.
    private func panelResignedKey() {
        // Focus left the showing on screen now. A new showing may replace it before this
        // runs (an announcement orders the panel out to give key back); that one is not
        // what lost focus.
        let showing = chrome.showCount
        DispatchQueue.main.async { [weak self] in
            guard let self, let panel = self.panel, panel.isVisible, self.chrome.showCount == showing else { return }
            let otherKey = NSApp.keyWindow.map { $0 !== panel } ?? false
            guard let reason = PopupFocusRule.reasonAfterResigningKey(
                panelStillKey: panel.isKeyWindow,
                newKeyWindowIsOurs: otherKey,
                dismissalSuspended: self.suspendsDismissal,
                showingAnnouncement: self.showingAnnouncement
            ) else { return }
            self.hide(reason: reason)
        }
    }

    /// Another of our windows became key: hide at once, and keep the session.
    ///
    /// Not an announcement: it never had focus to lose, and handing focus back when it
    /// replaces a card may itself make one of our windows key (History, when the app is
    /// active); it stays up over that window until its timer or a click ends it.
    private func ownWindowBecameKey(_ window: NSWindow) {
        guard let panel, panel.isVisible, window !== panel, !suspendsDismissal, !showingAnnouncement else { return }
        hide(reason: .ownWindowFocused)
    }

    /// A mouse-down anywhere outside this app. It covers clicks that change no key
    /// window: the menu bar, the Dock, a panel opened from Services that never got key.
    func outsideMouseDown() {
        guard isVisible else { return }
        dismiss()
    }

    /// Esc as the app's local key monitor sees it, wherever in the app it was pressed.
    /// True when the panel took it; false leaves it to the window it was meant for.
    func localEscape() -> Bool {
        guard isVisible,
              PopupFocusRule.takesEscape(panelIsKey: isKey, showingAnnouncement: showingAnnouncement)
        else { return false }
        dismiss()
        return true
    }

    private func installMonitors() {
        let before = monitorState
        defer {
            let after = monitorState
            let added = [after.global && !before.global, after.local && !before.local, after.observer && !before.observer]
            monitorInstalls += added.filter { $0 }.count
        }
        if globalMonitor == nil {
            globalMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.outsideMouseDown() }
            }
        }
        if localMonitor == nil {
            // Belt and braces for Esc: the panel's sendEvent sees it first when it is key.
            // An announcement over one of our windows leaves Esc to that window.
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard event.keyCode == TranslationPanel.escapeKeyCode else { return event }
                let handled = MainActor.assumeIsolated { self?.localEscape() ?? false }
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
