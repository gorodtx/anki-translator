import AppKit
import SwiftUI
import TranslatorCore

/// Native hidden-window checks of the production surface. No backend connection,
/// pasteboard, permissions, installed application, user database or global appearance.
@main
struct PopupAppearanceCheck {
    @MainActor
    static func main() throws {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        let model = AppModel(client: IPCClient(socketPath: "/nonexistent/popup-appearance-check.sock"))
        model.state = ViewState(
            original: "Loved", translation: "любимый; любовь; любить",
            canRefreshExamples: true,
            apple: AppleLexical(
                headword: "love", ipaUk: "lʌv", ipaUs: "ləv",
                entries: [AppleEntry(pos: "noun", senses: [
                    AppleSense(index: 1, translation: "любовь", examples: [
                        ExamplePair(en: "a love of adventure", ru: "любовь к приключениям"),
                    ]),
                ])]
            )
        )
        let initialState = model.state
        var failures = 0
        func check(_ passed: Bool, _ name: String) {
            print("\(passed ? "PASS" : "FAIL") \(name)")
            if !passed { failures += 1 }
        }

        for appearance in [NSAppearance.Name.aqua, .darkAqua,
                           .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua] {
            app.appearance = NSAppearance(named: appearance)
            let root = TranslationPopupView(
                model: model, chrome: PopupChrome(),
                onNaturalHeight: { _ in }, onActivate: { _ in }
            )
            let host = NSHostingView(rootView: root)
            host.sizingOptions = []
            host.autoresizingMask = [.width, .height]
            let bounds = NSRect(x: 0, y: 0, width: PopupLayout.narrowWidth, height: 400)
            let window = TranslationPanel()
            window.setContentSize(bounds.size)
            window.appearance = app.appearance
            let surface = PopupPanelController.makeSurface(content: host, bounds: bounds)
            window.contentView = surface
            PopupPanelController.roundSurface(surface)
            surface.layoutSubtreeIfNeeded()
            let glass = surface.subviews.compactMap { $0 as? NSGlassEffectView }.first
            let name = appearance.rawValue
            check(glass?.contentView === host, "\(name): hosting is glass contentView")
            check(surface.subviews.count == 1 && glass != nil, "\(name): one glass, no sibling text")
            check(host.isDescendant(of: glass ?? NSView()), "\(name): text receives glass treatment")
            check(glass?.style == .regular && glass?.cornerRadius == PopupPanelController.cornerRadius,
                  "\(name): regular glass and existing radius")
            check(host.sizingOptions.isEmpty, "\(name): controller remains sole window-size owner")
            check(surface.superview?.layer?.cornerRadius == PopupPanelController.cornerRadius
                  && surface.superview?.layer?.masksToBounds == true,
                  "\(name): attached window root keeps rounded edge/shadow")
            for size in [NSSize(width: PopupLayout.wideWidth, height: 650), bounds.size] {
                window.setContentSize(size)
                surface.layoutSubtreeIfNeeded()
                check(host.frame.size == size, "\(name): content follows \(Int(size.width))x\(Int(size.height))")
            }
            check(!window.isVisible, "\(name): no desktop window shown")
            window.close()
        }
        check(model.state == initialState, "fixture translation state unchanged")
        check(model.connection == .idle, "IPC never started")
        check(PopupFooter.rows(for: model).map(\.row) == [.addToAnki, .copyTranslation, .newExamples],
              "existing footer actions unchanged")
        print("OFFSCREEN ONLY: view hierarchy and geometry; background adaptation/pixels unverified")
        exit(failures == 0 ? 0 : 1)
    }
}
