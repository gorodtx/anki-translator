import AppKit
import SwiftUI
import TranslatorCore

/// The shortcut recorder, built as `KeyboardShortcuts.Recorder` (Maccy's) is: a search
/// field with no magnifier, its text centred, the combination as its value and the field's
/// own clear button to remove it. Being a real bezelled field it has visible bounds in
/// both appearances and the system focus ring while it listens.
struct ShortcutRecorder: NSViewRepresentable {
    var combo: KeyCombo?
    var onChange: (KeyCombo?) -> Void
    /// True while the field listens for keys, so the registered shortcut can step aside;
    /// false when listening ends with nothing new, so it comes back. A new combination (or
    /// none, after Delete) arrives through `onChange` instead of a false here.
    var onRecordingChange: (Bool) -> Void

    func makeNSView(context: Context) -> ShortcutRecorderField {
        let field = ShortcutRecorderField()
        field.onChange = onChange
        field.onRecordingChange = onRecordingChange
        field.combo = combo
        return field
    }

    func updateNSView(_ field: ShortcutRecorderField, context: Context) {
        field.onChange = onChange
        field.onRecordingChange = onRecordingChange
        if field.combo != combo { field.combo = combo }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: ShortcutRecorderField, context: Context) -> CGSize? {
        CGSize(width: ShortcutRecorderField.width, height: nsView.intrinsicContentSize.height)
    }
}

final class ShortcutRecorderField: NSSearchField, NSSearchFieldDelegate {
    static let width: CGFloat = 130
    private static let emptyPrompt = "Record Shortcut"
    private static let listeningPrompt = "Press Shortcut"

    /// The field on screen, so a setup row can send the user straight to it.
    static weak var current: ShortcutRecorderField?

    var onChange: ((KeyCombo?) -> Void)?
    var onRecordingChange: ((Bool) -> Void)?

    var combo: KeyCombo? {
        didSet { if !isRecording { showCombo() } }
    }

    private var monitor: Any?
    private(set) var isRecording = false

    init() {
        super.init(frame: CGRect(x: 0, y: 0, width: Self.width, height: 22))
        delegate = self
        alignment = .center
        focusRingType = .default
        (cell as? NSSearchFieldCell)?.searchButtonCell = nil
        if let cancel = (cell as? NSSearchFieldCell)?.cancelButtonCell {
            cancel.target = self
            cancel.action = #selector(clear)
        }
        setAccessibilityLabel("Shortcut")
        setAccessibilityHelp("Click, then press the keys to use. Escape cancels, Delete removes it.")
        showCombo()
        ShortcutRecorderField.current = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: Self.width, height: super.intrinsicContentSize.height)
    }

    private func showCombo() {
        stringValue = combo?.displayString ?? ""
        placeholderString = Self.emptyPrompt
        setAccessibilityValue(combo?.displayString ?? "None")
    }

    // MARK: - Recording

    /// Set for the length of an explicit request to listen: a button, VoiceOver's press
    /// or its focus. Those arrive through the accessibility API or an action, and
    /// `NSApp.currentEvent` is then whatever event came last, not what asked.
    private var explicitRequest = false

    /// Focus only from the user's own click or Tab, or an explicit request, never from a
    /// window opening or a pane switching: a field that took focus on its own would
    /// swallow the next keys typed.
    override func becomeFirstResponder() -> Bool {
        let fromInput = NSApp.currentEvent.map { [.leftMouseDown, .keyDown, .leftMouseUp].contains($0.type) } ?? false
        guard explicitRequest || fromInput else { return false }
        let accepted = super.becomeFirstResponder()
        if accepted { startRecording() }
        return accepted
    }

    /// Starts listening, as a click in the field does. Used by the setup checklist's
    /// button and by VoiceOver.
    func beginRecording() {
        explicitRequest = true
        defer { explicitRequest = false }
        window?.makeFirstResponder(self)
    }

    override func accessibilityPerformPress() -> Bool {
        beginRecording()
        return isRecording
    }

    override func setAccessibilityFocused(_ accessibilityFocused: Bool) {
        if accessibilityFocused, !isRecording {
            beginRecording()
        } else {
            super.setAccessibilityFocused(accessibilityFocused)
        }
    }

    private func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        stringValue = ""
        // A new placeholder restarts the field editor, which ends editing on the way; that
        // end is ours and must not end listening. Seen when listening starts from a button
        // or VoiceOver: the field is already being edited when this runs.
        restartingEditor = true
        placeholderString = Self.listeningPrompt
        restartingEditor = false
        onRecordingChange?(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged, .leftMouseDown]) { [weak self] event in
            let passes = MainActor.assumeIsolated {
                guard let self, self.isRecording else { return true }
                return self.handle(event)
            }
            return passes ? event : nil
        }
    }

    /// Whether the event goes on to the window once the recorder has seen it.
    private func handle(_ event: NSEvent) -> Bool {
        switch event.type {
        case .leftMouseDown:
            // A click anywhere else ends listening; the click itself goes through. A click
            // inside may be the clear button, which has its own action.
            let inside = event.window === window && bounds.contains(convert(event.locationInWindow, from: nil))
            if !inside { stopRecording() }
            return true
        case .flagsChanged:
            // Show the modifiers as they are held, the way a system recorder does.
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            var text = ""
            if flags.contains(.control) { text += "⌃" }
            if flags.contains(.option) { text += "⌥" }
            if flags.contains(.shift) { text += "⇧" }
            if flags.contains(.command) { text += "⌘" }
            stringValue = text
            return true
        case .keyDown:
            let bare = event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty
            switch event.keyCode {
            case 53 where bare: // Escape: keep what was there
                stopRecording()
            case 51 where bare, 117 where bare: // Delete: no shortcut
                finishRecording(with: nil)
            case 48 where bare: // Tab moves on, as in any field
                stopRecording()
                return true
            default:
                guard let recorded = KeyComboRecorder.combo(from: event) else {
                    NSSound.beep()
                    break
                }
                if let conflict = ShortcutAvailability.conflict(for: recorded) {
                    refuse(recorded, because: conflict)
                } else {
                    finishRecording(with: recorded)
                }
            }
            return false
        default:
            return true
        }
    }

    /// Ends listening and gives the old combination back, which stepped aside for it.
    private func stopRecording() {
        guard endListening() else { return }
        onRecordingChange?(false)
    }

    /// Ends listening with a new combination (nil: none). The new one is handed over
    /// through `onChange` directly: giving the old one back first would register it again
    /// for nothing, and a taken one would announce itself right after the user fixed it.
    private func finishRecording(with new: KeyCombo?) {
        endListening()
        set(new)
    }

    /// Whether it was listening.
    @discardableResult
    private func endListening() -> Bool {
        guard isRecording else { return false }
        isRecording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        window?.makeFirstResponder(nil)
        showCombo()
        return true
    }

    /// The last combination refused and why, for the snapshot harness's probe.
    private(set) static var lastRefusal: (combo: KeyCombo, conflict: ShortcutConflict)?

    /// A combination a menu or the system already answers to: a hot key would take it
    /// from every app, so it is refused, and the alert names what uses it.
    private func refuse(_ combo: KeyCombo, because conflict: ShortcutConflict) {
        stopRecording()
        Self.lastRefusal = (combo, conflict)
        NSSound.beep()
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = conflict.message(for: combo)
        alert.informativeText = conflict.advice
        alert.addButton(withTitle: "OK")
        if let window {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }

    private func set(_ new: KeyCombo?) {
        combo = new
        showCombo()
        onChange?(new)
    }

    @objc private func clear() {
        if isRecording {
            finishRecording(with: nil)
        } else {
            set(nil)
        }
    }

    // MARK: - NSSearchFieldDelegate

    func controlTextDidEndEditing(_ notification: Notification) {
        guard !restartingEditor else { return }
        stopRecording()
    }

    /// Set while the field changes its own placeholder (see `startRecording`).
    private var restartingEditor = false

    private var resignObserver: NSObjectProtocol?

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        stopRecording()
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
        resignObserver = nil
        super.viewWillMove(toWindow: newWindow)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        // Keys typed in another app never reach the monitor, so listening ends with focus.
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: window, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.stopRecording() }
        }
    }
}
