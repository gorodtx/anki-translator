import AppKit
import SwiftUI
import TranslatorCore

/// Add to Anki: pick the values to send, then create a new note or update the notes that
/// already have this word. Mirrors the GTK dialog's decision model exactly.
///
/// Laid out like a settings pane (a right-aligned label column, controls stacked to its
/// right), with Cancel and the default button at the bottom right, outside any scrolling.
struct AnkiUpsertSheet: View {
    @Bindable var model: AppModel
    var openSettings: () -> Void
    var onFinished: (Bool) -> Void

    /// The window's size before the content has measured itself.
    static let initialSize = CGSize(width: Self.width, height: 300)
    private static let width: CGFloat = 510
    private static let placeholderHeight: CGFloat = 230

    private enum Phase: Equatable {
        case preparing
        case ready
        /// Settings lack what the backend needs; the sentence says what.
        case notSetUp(String)
        case failed(String)
    }

    @State private var phase: Phase = .preparing
    @State private var selectedTranslations: Set<Int> = []
    @State private var selectedDefinitions: Set<Int> = []
    @State private var selectedExamples: Set<Int> = []
    @State private var translationAction: FieldAction = .mergeUniqueSelected
    @State private var definitionsAction: FieldAction = .mergeUniqueSelected
    @State private var examplesAction: FieldAction = .mergeUniqueSelected
    @State private var imageAction: ImageAction = .keepExisting
    @State private var imagePath: String?
    @State private var createNew = true
    @State private var targetNoteIds: Set<Int> = []
    @State private var isApplying = false
    @State private var applyFailure: String?
    @State private var formHeight: CGFloat = 0
    /// The newest preparation this window started; an older one finishing late is ignored.
    @State private var preparation = UUID()

    var body: some View {
        VStack(spacing: 0) {
            switch phase {
            case .preparing:
                ProgressView {
                    Text(model.state.loading ? "Translating “\(currentSource.text)”…" : "Reading your Anki collection…")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .frame(height: Self.placeholderHeight)
            case let .notSetUp(instruction):
                // Its one way forward is the default button below, as in an alert.
                ContentUnavailableView(
                    "Anki Isn’t Set Up",
                    systemImage: "rectangle.stack",
                    description: Text(instruction)
                )
                .frame(height: Self.placeholderHeight)
            case let .failed(message):
                ContentUnavailableView(
                    "Can’t Read Anki",
                    systemImage: "exclamationmark.triangle",
                    description: Text(message)
                )
                .frame(height: Self.placeholderHeight)
            case .ready:
                if let preview = model.upsertPreview {
                    form(preview)
                }
            }
            footer
        }
        .frame(width: Self.width)
        .onAppear { prepare() }
        .onDisappear {
            // Closed: no preparation of ours is wanted any more.
            preparation = UUID()
            model.ankiNoteSource = nil
            model.abandonUpsertPreparation()
        }
        // Fixed in Settings while this window waited: carry on without being asked.
        .onChange(of: model.settings.anki) {
            if case .notSetUp = phase, AnkiSetupGap.gaps(in: model.settings.anki).isEmpty {
                prepare()
            }
        }
        // Another lookup while this window is open — a new word, a history entry, the
        // popup dismissed — drops the note the backend prepared, and Add would fail.
        .onChange(of: lookup) { followLookup() }
    }

    // MARK: - The lookup underneath

    /// The lookup the app holds now, in the terms the note was prepared from.
    private var currentSource: AnkiNoteSource {
        AnkiNoteSource(
            text: model.state.originalText.trimmingCharacters(in: .whitespacesAndNewlines),
            requestId: model.activeRequestId,
            closedSessions: model.closedSessions,
            finished: !model.state.loading
        )
    }

    private struct Lookup: Equatable {
        var source: AnkiNoteSource
        var loading: Bool
        var canAdd: Bool
    }

    private var lookup: Lookup {
        Lookup(source: currentSource, loading: model.state.loading, canAdd: model.state.canAddAnki)
    }

    /// Follows a new lookup: prepares the note again from it once it has finished, and
    /// closes when there is nothing left to add from.
    private func followLookup() {
        let now = lookup
        switch AnkiSheetFollowUp.after(
            preparedFrom: model.ankiNoteSource, now: now.source, loading: now.loading, canAdd: now.canAdd
        ) {
        case .keep:
            break
        case .wait:
            preparation = UUID()
            model.abandonUpsertPreparation()
            applyFailure = nil
            phase = .preparing
        case .prepare:
            prepare()
        case .close:
            onFinished(false)
        }
    }

    // MARK: - Form

    /// The tallest the form may be before it scrolls: what the screen has left once the
    /// title bar and the button row are placed.
    private var formCap: CGFloat {
        let screen = NSScreen.main?.visibleFrame.height ?? 800
        return max(240, screen - 28 - 72 - 80)
    }

    private var formScrolls: Bool { formHeight > formCap }

    private func form(_ preview: UpsertPreview) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                SettingsPane {
                    sections(preview)
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { formHeight = $0 }
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(height: formHeight > 0 ? min(formHeight, formCap) : nil)
            if formScrolls { Divider() }
        }
    }

    @ViewBuilder
    private func sections(_ preview: UpsertPreview) -> some View {
        SettingsSection(title: "Word") {
            // The word the values below were prepared from, not whatever the popup shows.
            Text(model.ankiNoteSource?.text ?? "")
                .lineLimit(2)
                .textSelection(.enabled)
        }
        SettingsSection(title: "Deck") { deckPicker }
        SettingsSection(title: "Note Type") {
            // The same pop-up as in Settings; a new note type has other fields, so the
            // preview is made again for it.
            if model.ankiNoteTypesSupported {
                AnkiNoteTypePicker(model: model) { prepare() }
            } else {
                Text(model.settings.anki.model)
            }
        }

        SettingsDivider()

        if !preview.values.translations.isEmpty {
            SettingsSection(title: "Translations") {
                checkboxes(preview.values.translations, selection: $selectedTranslations)
            }
        }
        if !preview.values.definitionsEn.isEmpty {
            SettingsSection(title: "Definitions") {
                checkboxes(preview.values.definitionsEn, selection: $selectedDefinitions)
            }
        }
        if !preview.values.examplesEn.isEmpty {
            SettingsSection(title: "Examples") {
                checkboxes(preview.values.examplesEn, selection: $selectedExamples)
            }
        }
        SettingsSection(title: "Image") { imageControls(hasMatches: !preview.matches.isEmpty) }

        if !preview.matches.isEmpty {
            SettingsDivider()
            SettingsSection(title: "Note") { target(preview.matches) }
            SettingsSection(title: "Merge") { mergeGrid }
                .disabled(createNew)
        }
    }

    private func checkboxes(_ items: [String], selection: Binding<Set<Int>>) -> some View {
        ForEach(Array(items.enumerated()), id: \.offset) { index, item in
            SettingsToggle(title: item, isOn: Binding(
                get: { selection.wrappedValue.contains(index) },
                set: { on in
                    if on { selection.wrappedValue.insert(index) } else { selection.wrappedValue.remove(index) }
                }
            ))
        }
    }

    /// The deck is a pop-up of the collection's decks once Anki has listed them. Changing
    /// it changes the default deck (as Anki's own Add window does) and looks for matches
    /// in the new deck, since the matches found so far belong to the old one.
    private var deckPicker: some View {
        let current = model.settings.anki.deck
        let decks = model.ankiDecks.contains(current) ? model.ankiDecks : [current] + model.ankiDecks
        return Picker("Deck", selection: Binding(
            get: { current },
            set: { deck in
                guard deck != current else { return }
                model.settings.anki.deck = deck
                Task {
                    await model.selectDeck(deck)
                    prepare()
                }
            }
        )) {
            ForEach(decks, id: \.self) { Text($0).tag($0) }
        }
        .labelsHidden()
        .fixedSize()
        .disabled(model.ankiDecks.isEmpty)
        .help(model.ankiDecks.isEmpty ? "Anki hasn’t listed its decks. Is Anki running?" : "The deck the note goes to.")
    }

    @ViewBuilder
    private func imageControls(hasMatches: Bool) -> some View {
        HStack(spacing: 8) {
            Button("Choose…", action: chooseImage)
            if imagePath != nil {
                Button("Remove") {
                    imagePath = nil
                    imageAction = .keepExisting
                }
            }
        }
        if let imagePath {
            SettingsNote((imagePath as NSString).lastPathComponent)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(imagePath)
            if hasMatches {
                SettingsToggle(
                    title: "Replace the image on existing notes",
                    isOn: Binding(
                        get: { imageAction == .replaceWithSelected },
                        set: { imageAction = $0 ? .replaceWithSelected : .keepExisting }
                    )
                )
                .disabled(createNew)
            }
        }
    }

    @ViewBuilder
    private func target(_ matches: [UpsertMatch]) -> some View {
        Picker("Note", selection: $createNew) {
            Text("Create a new note").tag(true)
            Text(matches.count == 1 ? "Update the existing note" : "Update existing notes").tag(false)
        }
        .pickerStyle(.radioGroup)
        .labelsHidden()

        VStack(alignment: .leading, spacing: 6) {
            ForEach(matches) { match in
                SettingsToggle(
                    title: match.word,
                    description: match.translation.isEmpty ? nil : match.translation,
                    isOn: Binding(
                        get: { targetNoteIds.contains(match.noteId) },
                        set: { on in
                            if on { targetNoteIds.insert(match.noteId) } else { targetNoteIds.remove(match.noteId) }
                        }
                    )
                )
            }
        }
        // Under the radio button's title, since these belong to the second choice.
        .padding(.leading, 20)
        .disabled(createNew)
    }

    /// How each field of an existing note takes the selected values.
    private var mergeGrid: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 8) {
            mergeRow("Translations", selection: $translationAction)
            mergeRow("Definitions", selection: $definitionsAction)
            mergeRow("Examples", selection: $examplesAction)
        }
    }

    private static let mergeOrder: [FieldAction] = [.mergeUniqueSelected, .replaceWithSelected, .keepExisting]

    private func mergeRow(_ title: String, selection: Binding<FieldAction>) -> some View {
        GridRow {
            Text(title)
            Picker(title, selection: selection) {
                ForEach(Self.mergeOrder, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.radioGroup)
            .horizontalRadioGroupLayout()
            .labelsHidden()
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let status {
                Label {
                    Text(status.text)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: status.symbol)
                        .foregroundStyle(status.tint)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 12) {
                if isApplying {
                    ProgressView().controlSize(.small)
                }
                Spacer()
                Button {
                    onFinished(false)
                } label: {
                    Text("Cancel").frame(minWidth: 58)
                }
                .keyboardShortcut(.cancelAction)
                Button(action: primary.action) {
                    Text(primary.title).frame(minWidth: 58)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!primary.enabled)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        // The pane already ends in its own 20 pt margin; a scrolled form or a placeholder
        // does not.
        .padding(.top, phase == .ready && !formScrolls ? 0 : 20)
    }

    private struct Status {
        let text: String
        let symbol: String
        let tint: Color
    }

    private var status: Status? {
        if let applyFailure {
            return Status(text: applyFailure, symbol: "xmark.circle.fill", tint: .red)
        }
        if phase == .ready, !model.ankiStatus.available {
            return Status(
                text: "Anki isn’t running. Open Anki with AnkiConnect to add the note.",
                symbol: "exclamationmark.triangle.fill",
                tint: .yellow
            )
        }
        return nil
    }

    /// The default button: what moves this window forward in its current state.
    private var primary: (title: String, enabled: Bool, action: () -> Void) {
        switch phase {
        case .notSetUp:
            return ("Open Settings…", true, openSettings)
        case .failed:
            return ("Try Again", true, { prepare() })
        case .preparing:
            return ("Add", false, {})
        case .ready:
            return (createNew ? "Add" : "Update", canApply, { Task { await apply() } })
        }
    }

    private var canApply: Bool {
        guard phase == .ready, !isApplying, model.upsertPreview != nil else { return false }
        if createNew {
            return !selectedTranslations.isEmpty || !selectedDefinitions.isEmpty || !selectedExamples.isEmpty
        }
        return !targetNoteIds.isEmpty
    }

    // MARK: - Actions

    /// Prepares the note from the lookup the app holds now, and remembers which one that
    /// was: the Word row shows it, and a later lookup is measured against it.
    private func prepare() {
        let token = UUID()
        preparation = token
        model.ankiNoteSource = currentSource
        phase = .preparing
        applyFailure = nil
        formHeight = 0
        // Still translating: the backend has no result to prepare from yet, or only a
        // partial one. `followLookup` prepares once the lookup has finished.
        guard !model.state.loading else {
            model.abandonUpsertPreparation()
            return
        }
        Task { await finishPreparing(token) }
    }

    private func finishPreparing(_ token: UUID) async {
        async let status: Void = model.refreshAnkiStatus()
        await model.prepareUpsert()
        await status
        // A newer lookup or a closed window took over while this one was out.
        guard token == preparation else { return }
        guard let preview = model.upsertPreview else {
            let gaps = AnkiSetupGap.gaps(in: model.settings.anki)
            if let instruction = AnkiSetupGap.instruction(for: gaps) {
                phase = .notSetUp(instruction)
            } else {
                phase = .failed(model.banner?.text ?? "Anki didn’t answer.")
            }
            return
        }
        selectedTranslations = Set(preview.values.translations.indices)
        selectedDefinitions = Set(preview.values.definitionsEn.indices)
        selectedExamples = Set(preview.values.examplesEn.indices)
        imagePath = preview.values.imagePath
        imageAction = .keepExisting
        createNew = preview.matches.isEmpty
        targetNoteIds = preview.matches.first.map { [$0.noteId] } ?? []
        phase = .ready
        if model.ankiStatus.available, model.ankiDecks.isEmpty {
            await model.loadDecks()
        }
    }

    private func chooseImage() {
        let dialog = NSOpenPanel()
        dialog.allowsMultipleSelection = false
        dialog.canChooseDirectories = false
        dialog.allowedContentTypes = [.png, .jpeg, .gif, .webP, .heic]
        dialog.prompt = "Choose"
        let pick = { (response: NSApplication.ModalResponse) in
            guard response == .OK, let url = dialog.url else { return }
            imagePath = url.path
            imageAction = .replaceWithSelected
        }
        // A sheet on this window, as file dialogs are when a window asks for them.
        if let window = NSApp.keyWindow {
            dialog.beginSheetModal(for: window, completionHandler: pick)
        } else {
            pick(dialog.runModal())
        }
    }

    private func apply() async {
        guard let preview = model.upsertPreview else { return }
        isApplying = true
        applyFailure = nil
        defer { isApplying = false }
        let pick = { (items: [String], selected: Set<Int>) in
            items.indices.filter(selected.contains).map { items[$0] }
        }
        let decision = UpsertDecision(
            createNew: createNew,
            targetNoteIds: createNew ? [] : Array(targetNoteIds).sorted(),
            translationAction: translationAction,
            definitionsAction: definitionsAction,
            examplesAction: examplesAction,
            imageAction: imageAction,
            selectedTranslations: pick(preview.values.translations, selectedTranslations),
            selectedDefinitionsEn: pick(preview.values.definitionsEn, selectedDefinitions),
            selectedExamplesEn: pick(preview.values.examplesEn, selectedExamples),
            imagePath: imagePath
        )
        if await model.applyUpsert(decision) {
            onFinished(true)
        } else {
            // Stay open with the choices intact, and say why here: the popup that would
            // show the banner is not on screen.
            applyFailure = model.banner?.text ?? "Anki didn’t add the note."
        }
    }
}
