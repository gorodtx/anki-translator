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
/// - `TRANSLATOR_DEBUG_SNAPSHOT_SCENES` — any of `popup,settings,history` (default all).
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
        let raw = environment["TRANSLATOR_DEBUG_SNAPSHOT_SCENES"] ?? "popup,settings,history"
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
