import AppKit
import SwiftUI
import TranslatorCore

/// The panes of Settings, in toolbar order.
enum SettingsPaneID: String, CaseIterable {
    case general
    case sources
    case anki
    case advanced

    var title: String {
        switch self {
        case .general: return "General"
        case .sources: return "Sources"
        case .anki: return "Anki"
        case .advanced: return "Advanced"
        }
    }

    /// Checked at run time too: a symbol that does not exist would leave a blank item.
    var symbol: String {
        switch self {
        case .general: return "gearshape"
        case .sources: return "character.book.closed"
        case .anki: return "rectangle.stack"
        case .advanced: return "gearshape.2"
        }
    }

    fileprivate var toolbarIdentifier: NSToolbarItem.Identifier {
        NSToolbarItem.Identifier("settings.\(rawValue)")
    }
}

/// The Settings window, built the way sindresorhus/Settings (which Maccy uses) builds it:
/// a standard titled window with a preference-style toolbar of panes, titled after the
/// selected pane, each pane its own size.
///
/// Made once and kept: reopening shows the same window with the same views, on the pane
/// it was left on, where it was left.
@MainActor
final class SettingsWindowController: NSWindowController, NSToolbarDelegate, NSWindowDelegate {
    private static let selectedPaneKey = "SettingsSelectedPane"
    private static let frameName = "Settings"
    /// sindresorhus/Settings animates the frame over 0.25 s; the system's own is close.
    private static let resizeDuration: TimeInterval = 0.25

    private let model: AppModel
    private let applyHotKey: (KeyCombo?) -> Void
    private let suspendHotKey: (Bool) -> Void

    private var panes: [SettingsPaneID: NSHostingController<AnyView>] = [:]
    private var sizeObservers: [SettingsPaneID: NSKeyValueObservation] = [:]
    private(set) var selectedPane: SettingsPaneID?
    private var hasBeenShown = false

    init(
        model: AppModel,
        applyHotKey: @escaping (KeyCombo?) -> Void,
        suspendHotKey: @escaping (Bool) -> Void
    ) {
        self.model = model
        self.applyHotKey = applyHotKey
        self.suspendHotKey = suspendHotKey
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 510, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: true
        )
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.toolbarStyle = .preference
        let content = NSView(frame: window.contentLayoutRect)
        // A pane caught mid-resize must not draw under the toolbar.
        content.clipsToBounds = true
        window.contentView = content
        super.init(window: window)
        window.delegate = self

        let toolbar = NSToolbar(identifier: "SettingsToolbar")
        toolbar.delegate = self
        toolbar.allowsUserCustomization = false
        toolbar.displayMode = .iconAndLabel
        window.toolbar = toolbar
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Showing

    /// Brings the window forward on `pane`, or on the pane it was left on.
    func show(pane: SettingsPaneID? = nil) {
        let target = pane ?? selectedPane ?? Self.storedPane ?? .general
        select(target, animated: false)
        guard let window else { return }
        if !hasBeenShown {
            hasBeenShown = true
            window.center()
            window.setFrameUsingName(Self.frameName)
            window.setFrameAutosaveName(Self.frameName)
            // The saved frame carries the height of whichever pane was open last.
            fitWindow(animated: false)
        }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        // Nothing is focused on open, as in System Settings: a focused shortcut field
        // would start listening for keys the moment the window appears.
        window.makeFirstResponder(nil)
    }

    /// Switches to `pane`, resizing the window to it with the top edge fixed.
    func select(_ pane: SettingsPaneID, animated: Bool = true) {
        guard let window, let contentView = window.contentView else { return }
        let controller = controller(for: pane)
        if selectedPane != pane || controller.view.superview == nil {
            if let old = selectedPane, old != pane { panes[old]?.view.removeFromSuperview() }
            let view = controller.view
            view.translatesAutoresizingMaskIntoConstraints = true
            // Glued to the top while the window grows or shrinks under it.
            view.autoresizingMask = [.minYMargin]
            let size = paneSize(controller)
            view.frame = CGRect(
                x: 0, y: contentView.bounds.height - size.height,
                width: size.width, height: size.height
            )
            contentView.addSubview(view)
            // A pane that was off screen has not followed the model; let it catch up
            // before its size is read.
            view.layoutSubtreeIfNeeded()
        }
        selectedPane = pane
        window.title = pane.title
        window.toolbar?.selectedItemIdentifier = pane.toolbarIdentifier
        UserDefaults.standard.set(pane.rawValue, forKey: Self.selectedPaneKey)
        fitWindow(animated: animated && window.isVisible)
        if window.isVisible { window.makeFirstResponder(nil) }
    }

    private static var storedPane: SettingsPaneID? {
        UserDefaults.standard.string(forKey: selectedPaneKey).flatMap(SettingsPaneID.init(rawValue:))
    }

    // MARK: - Panes

    private func controller(for pane: SettingsPaneID) -> NSHostingController<AnyView> {
        if let existing = panes[pane] { return existing }
        let controller = NSHostingController(rootView: view(for: pane))
        // One owner of the window size: this controller, from the pane's ideal size.
        controller.sizingOptions = [.preferredContentSize]
        panes[pane] = controller
        // A pane grows and shrinks with its content (a setup row done, a section opened).
        sizeObservers[pane] = controller.observe(\.preferredContentSize) { [weak self] _, _ in
            MainActor.assumeIsolated {
                guard let self, self.selectedPane == pane else { return }
                // Next turn: the change arrives mid-layout.
                DispatchQueue.main.async { self.fitWindow(animated: false) }
            }
        }
        return controller
    }

    private func view(for pane: SettingsPaneID) -> AnyView {
        switch pane {
        case .general:
            return AnyView(GeneralSettingsPane(
                model: model,
                applyHotKey: applyHotKey,
                suspendHotKey: suspendHotKey
            ))
        case .sources:
            return AnyView(SourcesSettingsPane(model: model))
        case .anki:
            return AnyView(AnkiSettingsPane(model: model))
        case .advanced:
            return AnyView(AdvancedSettingsPane(model: model))
        }
    }

    private func paneSize(_ controller: NSHostingController<AnyView>) -> CGSize {
        let preferred = controller.preferredContentSize
        if preferred.width > 0, preferred.height > 0 { return preferred }
        return controller.view.fittingSize
    }

    /// Sizes the window to the selected pane, keeping the top edge where it is and moving
    /// up only as far as the bottom of the screen needs.
    private func fitWindow(animated: Bool) {
        guard let window, let pane = selectedPane, let controller = panes[pane] else { return }
        let size = paneSize(controller)
        guard size.width > 0, size.height > 0 else { return }
        var target = window.frameRect(forContentRect: CGRect(origin: .zero, size: size))
        target.origin.x = window.frame.minX
        target.origin.y = window.frame.maxY - target.height
        if let visible = (window.screen ?? NSScreen.main)?.visibleFrame {
            target.origin.y = max(target.origin.y, visible.minY)
            target.origin.y = min(target.origin.y, visible.maxY - target.height)
        }
        if animated, target != window.frame {
            isAnimatingFrame = true
            NSAnimationContext.runAnimationGroup { context in
                context.duration = Self.resizeDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().setFrame(target, display: true)
            } completionHandler: {
                MainActor.assumeIsolated {
                    self.isAnimatingFrame = false
                    // The pane may have changed size while the frame moved (a pane shown
                    // for the first time lays out only once it is in the window).
                    self.fitWindow(animated: false)
                }
            }
            return
        }
        // A frame set now would be overridden by the running animation's end; its
        // completion fits again with the size as it is then.
        guard !isAnimatingFrame else { return }
        if target != window.frame { window.setFrame(target, display: true) }
        guard let contentView = window.contentView else { return }
        controller.view.frame = CGRect(
            x: 0, y: contentView.bounds.height - size.height,
            width: size.width, height: size.height
        )
    }

    private var isAnimatingFrame = false

    // MARK: - NSWindowDelegate

    func windowDidBecomeKey(_ notification: Notification) {
        // Read from the system every time: a permission or a login item can change in
        // System Settings while this window is in the background, and nobody tells us.
        model.refreshAccessibilityTrust()
        model.refreshLoginItem()
        Task { await model.refreshAll() }
    }

    // MARK: - NSToolbarDelegate

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        SettingsPaneID.allCases.map(\.toolbarIdentifier)
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        guard let pane = SettingsPaneID.allCases.first(where: { $0.toolbarIdentifier == itemIdentifier }) else {
            return nil
        }
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = pane.title
        item.paletteLabel = pane.title
        item.image = NSImage(systemSymbolName: pane.symbol, accessibilityDescription: pane.title)
        if item.image == nil { NSLog("[settings] missing SF Symbol \(pane.symbol)") }
        item.target = self
        item.action = #selector(selectFromToolbar(_:))
        return item
    }

    @objc private func selectFromToolbar(_ sender: NSToolbarItem) {
        guard let pane = SettingsPaneID.allCases.first(where: { $0.toolbarIdentifier == sender.itemIdentifier }) else {
            return
        }
        select(pane, animated: true)
    }
}
