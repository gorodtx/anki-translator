import SwiftUI
import TranslatorCore

/// Anki: whether AnkiConnect answers, where cards go, and which field of the note type
/// takes which value.
struct AnkiSettingsPane: View {
    @Bindable var model: AppModel

    @State private var isChecking = false

    private var connected: Bool { model.ankiStatus.available }
    private var issues: [AnkiFieldIssue] { model.ankiFieldIssues }

    var body: some View {
        SettingsPane {
            SettingsSection(title: "Connection") {
                SettingsStatus(
                    level: isChecking ? .working : (connected ? .ok : .warning),
                    title: connected ? "Connected to Anki" : "Anki isn’t running",
                    note: connected ? nil : "Open Anki with the AnkiConnect add-on to add cards."
                )
                SettingsStatusDetail {
                    Button("Check Again") { Task { await check() } }
                        .disabled(isChecking || !model.isConnected)
                }
            }

            SettingsDivider()

            SettingsSection(title: "Deck") { deckPicker }
            SettingsSection(title: "Note Type") { noteType }

            SettingsDivider()

            SettingsSection(title: "Fields") { fields }
        }
        .task { await check() }
    }

    // MARK: - Deck and note type

    /// The collection's decks once Anki has listed them; until then the configured deck,
    /// shown but not changeable, since there is nothing to choose from.
    private var deckPicker: some View {
        let current = model.settings.anki.deck
        let decks = model.ankiDecks.contains(current) || current.isEmpty
            ? model.ankiDecks
            : [current] + model.ankiDecks
        return Picker("Deck", selection: Binding(
            get: { current },
            set: { deck in
                guard deck != current else { return }
                // Saved with the rest of the settings; the backend also makes it the
                // default deck, as Anki's own Add window does.
                model.settings.anki.deck = deck
                Task { await model.selectDeck(deck) }
            }
        )) {
            if decks.isEmpty { Text("None").tag("") }
            ForEach(decks, id: \.self) { Text($0).tag($0) }
        }
        .labelsHidden()
        .fixedSize()
        .disabled(model.ankiDecks.isEmpty)
        .help(model.ankiDecks.isEmpty ? "Anki hasn’t listed its decks. Is Anki running?" : "The deck new cards go to.")
    }

    @ViewBuilder
    private var noteType: some View {
        let name = model.settings.anki.model
        let ready = model.ankiStatus.modelStatus.localizedCaseInsensitiveContains("ready")
        if !connected {
            Text(name.isEmpty ? "None" : name)
        } else if ready {
            SettingsStatus(level: .ok, title: name.isEmpty ? "Translator" : name)
        } else {
            SettingsStatus(
                level: .warning,
                title: name.isEmpty ? "None" : name,
                note: "Anki has no note type for this app yet. Creating one adds the five fields it fills in."
            )
            SettingsStatusDetail {
                Button("Create Note Type") {
                    Task {
                        await model.createModel()
                        // The backend points the settings at the new note type; take them
                        // before the next change here saves the old ones over them.
                        await model.refreshSettings()
                        await model.refreshAnkiStatus()
                        await model.loadModelFields()
                    }
                }
            }
        }
    }

    // MARK: - Fields

    private var fields: some View {
        VStack(alignment: .leading, spacing: 8) {
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 8, verticalSpacing: 6) {
                fieldRow("Word", text: $model.settings.anki.fields.word)
                fieldRow("Translation", text: $model.settings.anki.fields.translation)
                fieldRow("Example", text: $model.settings.anki.fields.exampleEn)
                fieldRow("Definitions", text: $model.settings.anki.fields.definitionsEn)
                fieldRow("Image", text: $model.settings.anki.fields.image)
            }
            ForEach(issues, id: \.configured) { issue in
                SettingsStatus(level: .warning, title: message(for: issue))
            }
            if let footer = fieldsFooter {
                SettingsNote(footer)
            }
        }
    }

    private func fieldRow(_ label: String, text: Binding<String>) -> some View {
        GridRow {
            Text(label)
                .gridColumnAlignment(.leading)
            TextField(label, text: text, prompt: Text("Field name"))
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .frame(width: 170)
                .overlay(alignment: .trailing) {
                    if issues.contains(where: { $0.configured == text.wrappedValue }) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                            .padding(.trailing, 5)
                            .accessibilityLabel("Not a field of the note type")
                    }
                }
        }
    }

    /// Naming the near miss turns a hunt into a correction.
    private func message(for issue: AnkiFieldIssue) -> String {
        if let suggestion = issue.suggestion {
            return "The note type has no “\(issue.configured)”. Did you mean “\(suggestion)”?"
        }
        return "The note type has no “\(issue.configured)”, so adding a card would fail."
    }

    /// What is known about the note type's fields, said plainly: compared, not askable,
    /// or nothing to compare against.
    private var fieldsFooter: String? {
        guard connected else { return "The note type’s field that takes each value." }
        if model.ankiModelFields.isEmpty {
            return model.ankiModelFieldsError ?? "The note type has no fields to compare against yet."
        }
        if issues.isEmpty { return "All five match the note type." }
        return "The note type has: \(model.ankiModelFields.joined(separator: ", "))."
    }

    // MARK: - Actions

    /// Asks Anki again, and when it answers, reads what the pane shows from it.
    private func check() async {
        isChecking = true
        defer { isChecking = false }
        await model.refreshAnkiStatus()
        guard model.ankiStatus.available else { return }
        async let decks: Void = model.loadDecks()
        async let fields: Void = model.loadModelFields()
        _ = await (decks, fields)
    }
}
