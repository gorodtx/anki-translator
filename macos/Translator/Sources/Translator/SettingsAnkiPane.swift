import SwiftUI
import TranslatorCore

/// Anki: whether AnkiConnect answers, where cards go, and which field of the note type
/// takes which value.
struct AnkiSettingsPane: View {
    @Bindable var model: AppModel

    @State private var isChecking = false

    /// The width of every control in the Fields grid, pop-up or text field alike.
    private static let fieldControlWidth: CGFloat = 170

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
            AnkiPopUpItems(current: current, listed: model.ankiDecks)
        }
        .labelsHidden()
        .frame(width: AnkiPopUpItems.width, alignment: .leading)
        .disabled(model.ankiDecks.isEmpty)
        .help(model.ankiDecks.isEmpty ? "Anki hasn’t listed its decks. Is Anki running?" : "The deck new cards go to.")
    }

    @ViewBuilder
    private var noteType: some View {
        if model.ankiNoteTypesSupported {
            AnkiNoteTypePicker(model: model, width: AnkiPopUpItems.width)
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
                    SettingsStatus(level: .warning, title: missingFieldsMessage)
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
            SettingsRowLabel(label)
                .gridColumnAlignment(.leading)
            if fieldsKnown {
                fieldPicker(label, selection: text)
            } else {
                TextField(label, text: text, prompt: Text("Field name"))
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .frame(width: Self.fieldControlWidth)
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
                Text(current).tag(current)
            }
        }
        .labelsHidden()
        // Leading, as the text fields in the same place are: a pop-up keeps a width of its
        // own, and a frame centres it, so each field's pop-up started somewhere else.
        .frame(width: Self.fieldControlWidth, alignment: .leading)
        .help(missing ? "“\(current)” is not a field of this note type." : "The field that takes the \(label.lowercased()).")
    }

    /// The names the pop-ups show that the note type does not have: they would fail when a
    /// card is added, so they are named, once, under the pop-ups.
    private var missingFieldsMessage: String {
        let names = issues.map { "“\($0.configured)”" }
        let noteType = model.settings.anki.model.isEmpty ? "the note type" : model.settings.anki.model
        // Not ListFormatter: it joins in the Mac's language, and this window is English.
        let list = names.joined(separator: ", ")
        return names.count == 1
            ? "\(list) isn’t a field of \(noteType). Choose one from the list."
            : "\(list) aren’t fields of \(noteType). Choose them from the lists."
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
    /// One width for the pop-ups of a column (the Anki pane passes `AnkiPopUpItems.width`);
    /// nil sizes the pop-up to its longest item.
    var width: CGFloat?
    var onChange: () async -> Void = {}

    var body: some View {
        sized(picker)
            .disabled(model.ankiNoteTypes.isEmpty)
            .help(model.ankiNoteTypes.isEmpty ? "Anki hasn’t listed its note types. Is Anki running?" : "The note type new cards are made with.")
            .task {
                // Add to Anki opens without the pane having asked.
                if model.ankiStatus.available, model.ankiNoteTypes.isEmpty { await model.loadNoteTypes() }
            }
    }

    @ViewBuilder
    private func sized(_ picker: some View) -> some View {
        if let width {
            picker.frame(width: width, alignment: .leading)
        } else {
            picker.fixedSize()
        }
    }

    private var picker: some View {
        let current = model.settings.anki.model
        return Picker("Note Type", selection: Binding(
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
            AnkiPopUpItems(current: current, listed: model.ankiNoteTypes)
        }
        .labelsHidden()
    }
}

/// The items of a Deck or Note Type pop-up. The selection always has an item to show:
/// "None" while nothing is chosen, and a configured name Anki did not list (or has not
/// listed yet) at the top, so the pop-up never draws an empty title. Neither is an empty
/// string item, which would be a blank row in the menu.
struct AnkiPopUpItems: View {
    let current: String
    let listed: [String]

    /// The width of the Deck and Note Type pop-ups in Settings, one for both so the column
    /// reads as a set; wide enough for a "Parent::Child" deck, longer names truncate.
    static let width: CGFloat = 200

    var body: some View {
        if current.isEmpty {
            Text("None").tag("")
            if !listed.isEmpty { Divider() }
        } else if !listed.contains(current) {
            Text(current).tag(current)
            if !listed.isEmpty { Divider() }
        }
        ForEach(listed, id: \.self) { Text($0).tag($0) }
    }
}
