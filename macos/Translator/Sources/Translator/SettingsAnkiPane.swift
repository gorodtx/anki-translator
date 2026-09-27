import SwiftUI
import TranslatorCore

/// Anki: whether AnkiConnect answers, where cards go, and which field of the note type
/// takes which value.
struct AnkiSettingsPane: View {
    @Bindable var model: AppModel

    @State private var isChecking = false

    private var connected: Bool { model.ankiStatus.available }
    private var issues: [AnkiFieldIssue] { model.ankiFieldIssues }
    /// Whether the app's own note type exists in the collection.
    private var appNoteTypeReady: Bool {
        model.ankiStatus.modelStatus.localizedCaseInsensitiveContains("ready")
    }

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
                if connected, let problem = model.settingsProblems[.anki] {
                    SettingsStatus(level: .error, title: problem)
                }
                SettingsUnsavedState(model: model)
            }

            SettingsDivider()

            Group {
                SettingsSection(title: "Deck") { deckPicker }
                SettingsSection(title: "Note Type") { noteType }

                SettingsDivider()

                SettingsSection(title: "Fields") { fields }
            }
            // Defaults until the backend's values are read; see SettingsUnsavedState.
            .disabled(!model.settingsLoaded)
        }
        // Again whenever Anki comes or goes: the pane is kept for the life of the app, and
        // a pane opened while Anki was closed would otherwise keep empty pop-ups after
        // the Connection row turned green.
        .task(id: connected) { await check() }
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
        if model.ankiNoteTypesSupported {
            AnkiNoteTypePicker(model: model)
            if connected, !appNoteTypeReady { createNoteType }
        } else {
            legacyNoteType
        }
    }

    /// The app's own note type is missing. Only a warning while nothing usable is chosen:
    /// a note type of the user's own is a choice, not a gap.
    @ViewBuilder
    private var createNoteType: some View {
        let current = model.settings.anki.model
        if current.isEmpty || !model.ankiNoteTypes.contains(current) {
            SettingsStatus(
                level: .warning,
                title: "Anki has no note type for this app yet.",
                note: "Creating one adds the five fields it fills in."
            )
        } else {
            SettingsNote("Or use this app’s own note type, with the five fields it fills in.")
        }
        SettingsStatusDetail {
            Button("Create Note Type") {
                Task {
                    await model.createModel()
                    // The backend points the settings at the new note type; take them
                    // before the next change here saves the old ones over them.
                    await model.refreshSettings()
                    await model.refreshAnkiStatus()
                    await model.loadNoteTypes()
                    await model.loadModelFields()
                }
            }
        }
    }

    /// A backend that cannot list note types: the configured one as text, as before.
    @ViewBuilder
    private var legacyNoteType: some View {
        let name = model.settings.anki.model
        if !connected {
            Text(name.isEmpty ? "None" : name)
        } else if appNoteTypeReady {
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
                        await model.refreshSettings()
                        await model.refreshAnkiStatus()
                        await model.loadModelFields()
                    }
                }
            }
        }
    }

    // MARK: - Fields

    /// Pop-ups of the note type's own fields once Anki has named them, so a name can only
    /// be one that exists. Text fields while it has not (Anki closed), so the mapping can
    /// still be set up ahead of time.
    private var fieldsKnown: Bool { !model.ankiModelFields.isEmpty }

    private var fields: some View {
        VStack(alignment: .leading, spacing: 8) {
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 8, verticalSpacing: 6) {
                fieldRow("Word", text: $model.settings.anki.fields.word)
                fieldRow("Translation", text: $model.settings.anki.fields.translation)
                fieldRow("Example", text: $model.settings.anki.fields.exampleEn)
                fieldRow("Definitions", text: $model.settings.anki.fields.definitionsEn)
                fieldRow("Image", text: $model.settings.anki.fields.image)
            }
            if fieldsKnown {
                if !issues.isEmpty {
                    SettingsStatus(
                        level: .warning,
                        title: issues.count == 1
                            ? "One value goes to a field this note type doesn’t have."
                            : "\(issues.count) values go to fields this note type doesn’t have."
                    )
                }
            } else {
                ForEach(issues, id: \.configured) { issue in
                    SettingsStatus(level: .warning, title: message(for: issue))
                }
                if let footer = fieldsFooter {
                    SettingsNote(footer)
                }
            }
        }
    }

    @ViewBuilder
    private func fieldRow(_ label: String, text: Binding<String>) -> some View {
        GridRow {
            Text(label)
                .gridColumnAlignment(.leading)
            if fieldsKnown {
                fieldPicker(label, selection: text)
            } else {
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
    }

    /// The note type's fields, plus None for a value that is not written, plus the
    /// configured name when the note type does not have it, so it stays visible (marked)
    /// instead of the pop-up silently showing something else.
    private func fieldPicker(_ label: String, selection: Binding<String>) -> some View {
        let names = model.ankiModelFields
        let current = selection.wrappedValue
        let missing = !current.isEmpty && !names.contains(current)
        return Picker(label, selection: selection) {
            Text("None").tag("")
            Divider()
            ForEach(names, id: \.self) { Text($0).tag($0) }
            if missing {
                Divider()
                Text("\(current) (not in this note type)").tag(current)
            }
        }
        .labelsHidden()
        .frame(width: 170)
        .help(missing ? "“\(current)” is not a field of this note type." : "The field that takes the \(label.lowercased()).")
    }

    /// Naming the near miss turns a hunt into a correction.
    private func message(for issue: AnkiFieldIssue) -> String {
        if let suggestion = issue.suggestion {
            return "The note type has no “\(issue.configured)”. Did you mean “\(suggestion)”?"
        }
        return "The note type has no “\(issue.configured)”, so adding a card would fail."
    }

    /// What is known about the note type's fields while there is no list to pick from.
    private var fieldsFooter: String? {
        guard connected else { return "The note type’s field that takes each value." }
        return model.ankiModelFieldsError ?? "The note type has no fields to compare against yet."
    }

    // MARK: - Actions

    /// Asks Anki again, and when it answers, reads what the pane shows from it.
    private func check() async {
        isChecking = true
        defer { isChecking = false }
        await model.refreshAnkiStatus()
        guard model.ankiStatus.available else { return }
        async let decks: Void = model.loadDecks()
        async let noteTypes: Void = model.loadNoteTypes()
        async let fields: Void = model.loadModelFields()
        _ = await (decks, noteTypes, fields)
    }
}

/// The note type cards are made with: a pop-up of the collection's note types once Anki
/// has listed them, and until then the configured one, shown but not changeable. Shared by
/// the Anki pane and the Add to Anki window, so the choice looks and works the same.
///
/// A new choice is saved at once and its fields are read again; `onChange` runs after.
struct AnkiNoteTypePicker: View {
    @Bindable var model: AppModel
    var onChange: () async -> Void = {}

    var body: some View {
        let current = model.settings.anki.model
        let types = model.ankiNoteTypes
        let items = types.contains(current) || current.isEmpty ? types : [current] + types
        Picker("Note Type", selection: Binding(
            get: { current },
            set: { name in
                guard name != current else { return }
                model.settings.anki.model = name
                Task {
                    await model.selectNoteType(name)
                    await onChange()
                }
            }
        )) {
            if items.isEmpty { Text("None").tag("") }
            ForEach(items, id: \.self) { Text($0).tag($0) }
        }
        .labelsHidden()
        .fixedSize()
        .disabled(types.isEmpty)
        .help(types.isEmpty ? "Anki hasn’t listed its note types. Is Anki running?" : "The note type new cards are made with.")
        .task {
            // Add to Anki opens without the pane having asked.
            if model.ankiStatus.available, types.isEmpty { await model.loadNoteTypes() }
        }
    }
}
