import AppKit
import SwiftUI
import TranslatorCore

/// Advanced: the parts that work behind the popup — the backend, the offline databases,
/// the Mac's own dictionary — and, folded away at the bottom, what runs in the background.
struct AdvancedSettingsPane: View {
    @Bindable var model: AppModel

    @State private var backgroundOpen = false

    private static let repository = URL(string: "https://github.com/gorodtx/selection_translator_anki")

    var body: some View {
        SettingsPane {
            SettingsSection(title: "Backend") {
                if model.isConnected {
                    SettingsStatus(
                        level: .ok,
                        title: "Running",
                        note: model.ping.map { "Version \($0.version)" }
                    )
                } else {
                    SettingsStatus(level: .error, title: "Not running", note: model.connectionSummary)
                }
            }

            SettingsSection(title: "Databases") { databases }

            SettingsSection(title: "Dictionary") { dictionary }

            SettingsDivider()

            SettingsSection(title: "") { about }
        }
        .onReceive(NotificationCenter.default.publisher(for: Self.snapshotDisclosure)) { note in
            backgroundOpen = note.object as? Bool ?? false
        }
    }

    /// Opens (object `true`) or closes "What runs here?" for the snapshot harness, which
    /// cannot click a window of an app that is not active.
    static let snapshotDisclosure = Notification.Name("TranslatorSettingsSnapshotDisclosure")

    // MARK: - Databases

    @ViewBuilder
    private var databases: some View {
        if let db = model.ping?.db {
            SettingsStatus(level: db.primary ? .ok : .warning, title: "Example sentences", note: db.primary ? nil : "Missing")
            SettingsStatus(level: db.fallback ? .ok : .warning, title: "More examples", note: db.fallback ? nil : "Missing")
            SettingsStatus(level: db.definitions ? .ok : .warning, title: "Definitions", note: db.definitions ? nil : "Missing")
            if !db.dir.isEmpty {
                SettingsStatusDetail {
                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: db.dir)])
                    }
                    .help(db.dir)
                }
            }
        } else {
            SettingsStatus(level: .unknown, title: "Unknown until the backend answers.")
        }
        if let problem = model.settingsProblems[.databases] {
            SettingsStatus(level: .error, title: problem)
        }
    }

    // MARK: - Dictionary

    @ViewBuilder
    private var dictionary: some View {
        if let step = model.setupPlan.steps.first(where: { $0.id == .dictionary }) {
            SettingsStatus(level: level(for: step.state), title: "Apple Dictionary", note: dictionaryNote(step))
            if let action = step.action, let label = step.actionLabel {
                SettingsStatusDetail {
                    Button(label) { SetupActions.perform(action, model: model) }
                }
            }
        }
    }

    private func level(for state: SetupState) -> SettingsStatusLevel {
        switch state {
        case .done: return .ok
        case .actionNeeded: return .warning
        case .waiting, .switchedOff: return .unknown
        }
    }

    private func dictionaryNote(_ step: SetupStep) -> String {
        guard step.state == .done else { return step.detail }
        let names = model.ping?.engines.dictionaries ?? []
        // One per line: the system's own names carry " - " inside them, and a comma run
        // broke inside a name so that a line began with "- ", which reads as a bullet.
        return names.isEmpty ? "Available." : names.joined(separator: "\n")
    }

    // MARK: - About

    /// The answer to a question asked once, usually after finding an unfamiliar process in
    /// Activity Monitor: whose is it, and what does it do. Folded away, because an answer
    /// nobody is asking is noise, and last, because it is not a setting.
    private var about: some View {
        VStack(alignment: .leading, spacing: 8) {
            DisclosureGroup(isExpanded: $backgroundOpen) {
                Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 10, verticalSpacing: 4) {
                    processRow("Translator", "This window, the shortcut and the popup.")
                    processRow("TranslatorEngine", "Keeps the offline dictionaries open so lookups are instant. Starts at login, then idles.")
                    processRow("TranslatorLookup", "Asks macOS for its dictionary and offline translation.")
                }
                .padding(.top, 4)
                SettingsNote("Nothing leaves this Mac unless Google or Cambridge is on in Sources.")
                    .padding(.top, 4)
            } label: {
                Text("What runs here?")
                    .font(.subheadline)
            }
            .accessibilityHint("Names the three background processes and what each one does.")

            if let repository = Self.repository {
                Link("Source Code on GitHub", destination: repository)
                    .font(.subheadline)
            }
        }
    }

    private func processRow(_ name: String, _ detail: String) -> some View {
        GridRow {
            Text(name)
                .font(.subheadline)
            SettingsNote(detail)
        }
        .accessibilityElement(children: .combine)
    }
}
