import AppKit
import SwiftUI
import TranslatorCore

extension AppModel {
    /// What a fresh install still has to do, from what the shell knows right now.
    var setupPlan: SetupPlan {
        SetupPlanner.plan(
            connected: isConnected,
            ping: ping,
            accessibilityTrusted: accessibilityTrusted,
            shortcutRegistered: shortcutRegistered,
            shortcut: hotKey?.displayString ?? "",
            loginItem: loginItem,
            anki: ankiStatus
        )
    }
}

/// The `Setup:` rows of the General pane: one per step that still stops the app from
/// working, each with its state, one line on what it is for, and the one button that
/// advances it. The pane shows none of this once setup is done.
///
/// Which steps are listed and what they say is decided by `SetupPlanner` (under test);
/// this only draws it and runs the actions.
struct SetupChecklist: View {
    @Bindable var model: AppModel
    /// Sends the user to the shortcut recorder on the same pane.
    var onRecordShortcut: () -> Void

    var body: some View {
        ForEach(model.setupPlan.checklist) { step in
            VStack(alignment: .leading, spacing: 6) {
                SettingsStatus(level: level(for: step), title: step.title, note: detail(for: step))
                SettingsStatusDetail {
                    if step.id == .databases, !model.databaseDownloads.isEmpty {
                        ProgressView(value: databaseFraction)
                            .progressViewStyle(.linear)
                            .controlSize(.small)
                            .frame(width: 200)
                        Button("Stop") { perform(.cancelDatabaseDownload) }
                    } else if let action = step.action, let label = step.actionLabel {
                        Button(label) { perform(action) }
                    }
                }
            }
        }
    }

    private func level(for step: SetupStep) -> SettingsStatusLevel {
        if step.id == .databases, !model.databaseDownloads.isEmpty { return .working }
        switch step.state {
        case .done: return .ok
        case .actionNeeded: return .warning
        case .switchedOff: return .unknown
        case .waiting:
            // A backend that is not running is the one failure here; everything else that
            // waits is unknown until it answers.
            return step.id == .backend && !model.isConnected ? .error : .unknown
        }
    }

    /// While files are arriving the row says which one and how far, because 1.8 GB with no
    /// sign of movement is indistinguishable from a stall.
    private func detail(for step: SetupStep) -> String {
        guard step.id == .databases, !model.databaseDownloads.isEmpty else { return step.detail }
        let active = model.databaseDownloads.values
            .filter { $0.state == .downloading || $0.state == .verifying }
            .sorted { $0.file < $1.file }
        guard let current = active.first else { return "Checking what arrived…" }
        let done = model.databaseDownloads.values.filter { $0.state == .done || $0.state == .present }
        let queue = model.databaseDownloads.count > 1
            ? " (\(done.count + 1) of \(model.databaseDownloads.count))"
            : ""
        if current.state == .verifying { return "Verifying \(current.file)\(queue)" }
        guard current.total > 0 else { return "Downloading \(current.file)\(queue)" }
        let received = ByteCountFormatter.string(fromByteCount: Int64(current.received), countStyle: .file)
        let total = ByteCountFormatter.string(fromByteCount: Int64(current.total), countStyle: .file)
        return "\(current.file) — \(received) of \(total)\(queue)"
    }

    /// One bar for the whole operation: per-file bars jumping back to zero read as failure.
    private var databaseFraction: Double {
        let files = model.databaseDownloads.values
        guard !files.isEmpty else { return 0 }
        let share = files.reduce(0.0) { total, file in
            switch file.state {
            case .done, .present: return total + 1
            case .downloading where file.total > 0:
                return total + Double(file.received) / Double(file.total)
            default: return total
            }
        }
        return share / Double(files.count)
    }

    private func perform(_ action: SetupAction) {
        SetupActions.perform(action, model: model, onRecordShortcut: onRecordShortcut)
    }
}

/// What each setup button does. Shared by the checklist and the panes that carry the
/// optional steps, so one button never behaves two ways.
@MainActor
enum SetupActions {
    static func perform(_ action: SetupAction, model: AppModel, onRecordShortcut: () -> Void = {}) {
        switch action {
        case .startBackend:
            startBackendAgent(model: model)
        case .grantAccessibility:
            // Raises Apple's own dialog; the click in it is the user's.
            SelectionCapture.requestTrust()
            SelectionCapture.openAccessibilitySettings()
            model.refreshAccessibilityTrust()
        case .openAccessibilitySettings:
            SelectionCapture.openAccessibilitySettings()
        case .recordShortcut:
            onRecordShortcut()
        case .downloadLanguagePair:
            // Only a SwiftUI `translationTask` can raise the system download sheet; the
            // Sources pane owns that control.
            break
        case .enableLoginItem:
            model.setLoginItem(true)
        case .openLoginItemsSettings:
            LoginItem.openSettings()
        case .downloadDatabases:
            Task { await model.downloadDatabases() }
        case .cancelDatabaseDownload:
            Task { await model.cancelDatabaseDownload() }
        case .openDictionarySettings:
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Dictionary.app"))
        case .connectAnki:
            Task {
                await model.refreshAnkiStatus()
                await model.loadDecks()
            }
        case .recheck:
            model.refreshAccessibilityTrust()
            Task { await model.refreshAll() }
        }
    }

    /// Ask launchd to run the login agent now.
    ///
    /// Its KeepAlive only covers a crash, so a backend stopped cleanly stays down until
    /// the next login. `kickstart` restarts a service that is still loaded; one that was
    /// booted out is not there to kick, so that case bootstraps the agent first.
    private static func startBackendAgent(model: AppModel) {
        let label = "com.translator.desktop"
        let domain = "gui/\(getuid())"
        if launchctl(["kickstart", "-k", "\(domain)/\(label)"]) != 0 {
            let plist = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/LaunchAgents/\(label).plist")
            _ = launchctl(["bootstrap", domain, plist.path])
        }
        Task {
            // It opens three SQLite bases and warms the sidecar before it answers.
            try? await Task.sleep(for: .seconds(8))
            await model.refreshAll()
        }
    }

    @discardableResult
    private static func launchctl(_ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return -1
        }
    }
}
