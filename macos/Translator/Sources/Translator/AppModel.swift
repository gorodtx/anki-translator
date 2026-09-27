import AppKit
import Observation
import SwiftUI
import TranslatorCore

/// Single source of truth for the shell: backend connection, current translation, history,
/// Anki state, settings. Views observe it; nothing else talks to `IPCClient` directly.
@MainActor
@Observable
final class AppModel {
    // Connection
    var connection: IPCClient.ConnectionState = .idle
    var ping: PingInfo?

    // Current translation
    var state = ViewState()
    var activeRequestId: Int = 0
    var phase: TranslationPhase = .final
    /// Why the current lookup failed, said as the body of the panel.
    var lastError: String?
    /// How serious `lastError` is: an error, or a warning the backend gave as the reason
    /// ("Every translation source is switched off." is a setting, not a fault).
    var lastErrorLevel: NotificationLevel = .error

    // Ambient
    var banner: BannerMessage?
    /// Whether the app opens itself at login. Read from the system, never remembered:
    /// the user can change it in System Settings without the app hearing about it.
    var loginItem: LoginItemState = .notRegistered
    /// The note type's real field names, and why they could not be read. Empty with no
    /// error means nothing can be concluded, which is not the same as a mismatch.
    var ankiModelFields: [String] = []
    var ankiModelFieldsError: String?
    /// Progress per database file while a download runs; empty when none is.
    var databaseDownloads: [String: DatabaseProgressEvent] = [:]
    var history: [HistoryItem] = []
    /// Why the last load of the history failed; nil once one succeeds. The History window
    /// says so instead of claiming there is no history.
    var historyLoadError: String?
    /// Why an entry could not be opened, for the History window to report.
    var historyOpenFailure: HistoryOpenFailure?
    /// Counts the History window's reopenings, each after its list has been reloaded.
    var historyReopens = 0
    var ankiStatus = AnkiStatus()
    var ankiDecks: [String] = []
    /// The collection's note types, once Anki has listed them.
    var ankiNoteTypes: [String] = []
    /// False against a backend that predates `anki.model_names`: Settings then shows the
    /// note type as text, as it did before there was a list to choose from.
    var ankiNoteTypesSupported = true
    /// What went wrong in Settings, by where it is shown. Settings has no popup banner to
    /// say it in, so each pane shows its own; a success clears the entry.
    var settingsProblems: [SettingsProblem: String] = [:]
    /// What the backend runs with. Settings apply as they change, as a Mac settings window
    /// does: every change schedules a save (see `scheduleSettingsSave`), whoever made it —
    /// a Settings pane, or the deck pop-up of Add to Anki.
    var settings = BackendSettings() {
        didSet { scheduleSettingsSave() }
    }
    /// The global shortcut; nil when the user cleared it (Services still works).
    var hotKey: KeyCombo? = KeyCombo.defaultCombo
    var accessibilityTrusted: Bool = SelectionCapture.isTrusted
    /// Whether the current combination actually registered; another app may own it.
    var shortcutRegistered = true
    var appleTranslationReady = false

    // Anki sheet
    var upsertPreview: UpsertPreview?
    var isPreparingUpsert = false
    /// The lookup the Add to Anki window prepared its note from; the Word row shows it.
    var ankiNoteSource: AnkiNoteSource?
    /// How many times the backend session has been closed. Closing drops the note Add to
    /// Anki prepared, so the window watches this.
    private(set) var closedSessions = 0
    /// The newest preparation; an older one answering late must not replace its preview.
    @ObservationIgnored private var upsertPreparation = 0

    /// Where a Settings failure is shown.
    enum SettingsProblem: Hashable {
        /// General > Startup.
        case loginItem
        /// The Sources and Anki panes: a change the backend did not take.
        case save
        /// Advanced > Databases and the Setup row for them.
        case databases
        /// Anki > Connection: decks, note types, the deck or note type chosen.
        case anki
    }

    private let client: IPCClient
    /// What the backend is known to hold, and whether the last save of a change failed.
    private(set) var settingsSync = SettingsSync<BackendSettings>()
    /// The debounced save of a change, while it waits.
    @ObservationIgnored private var pendingSettingsSave: Task<Void, Never>?
    /// Saves sent and not answered yet; a load meanwhile would bring back the old values.
    @ObservationIgnored private var settingsSavesInFlight = 0
    private var bannerDismissTask: Task<Void, Never>?
    /// The last warning the backend sent, so an error phase can say why instead of
    /// "Translation failed."
    private var pendingNotice: (text: String, level: NotificationLevel)?

    struct BannerMessage: Equatable, Identifiable {
        let id = UUID()
        var text: String
        var level: NotificationLevel
    }

    struct HistoryOpenFailure: Equatable, Identifiable {
        let id = UUID()
        var word: String
        var message: String
    }

    init(client: IPCClient) {
        self.client = client
        client.onEvent = { [weak self] event in self?.handle(event) }
        client.onStateChange = { [weak self] state in self?.handle(connection: state) }
    }

    var isConnected: Bool { connection == .connected }

    var connectionSummary: String {
        switch connection {
        case .idle: return "Not connected"
        case let .connecting(attempt): return "Connecting… (\(attempt))"
        case .connected: return "Connected"
        case let .failed(message): return message
        }
    }

    // MARK: - Lifecycle

    func start() {
        client.start()
    }

    func stop() {
        client.stop()
    }

    private func handle(connection state: IPCClient.ConnectionState) {
        connection = state
        guard state == .connected else { return }
        Task { await refreshAll() }
    }

    func refreshAll() async {
        async let ping: Void = refreshPing()
        async let settings: Void = refreshSettings()
        async let anki: Void = refreshAnkiStatus()
        _ = await (ping, settings, anki)
    }

    // MARK: - Events

    private func handle(_ event: IPCEvent) {
        switch event.name {
        case IPCEventName.translationState:
            guard let payload = try? event.decode(TranslationStateEvent.self) else { return }
            guard payload.requestId >= activeRequestId else { return }  // stale request
            activeRequestId = payload.requestId
            phase = payload.phase
            let wasLoading = state.loading
            withAnimation(Motion.stateChange) { state = payload.state }
            // The backend names the reason in a notification just before it reports the
            // error — "Every translation source is switched off." is not a failure to
            // retry, and calling it one sends the user looking for a fault.
            if payload.phase == .error {
                lastError = pendingNotice?.text ?? "Translation failed."
                lastErrorLevel = pendingNotice?.level ?? .error
            }
            pendingNotice = nil
            lookupSettled(wasLoading: wasLoading)
        case IPCEventName.notification:
            guard let payload = try? event.decode(NotificationEvent.self) else { return }
            if payload.level != .info { pendingNotice = (payload.message, payload.level) }
            show(banner: payload.message, level: payload.level)
        case IPCEventName.dbProgress:
            guard let payload = try? event.decode(DatabaseProgressEvent.self) else { return }
            apply(databaseProgress: payload)
        case IPCEventName.ankiAvailability:
            guard let payload = try? event.decode(AnkiAvailabilityEvent.self) else { return }
            ankiStatus.available = payload.available
        case IPCEventName.disconnected:
            // A lookup still waiting will never finish; saying "No translation" would
            // blame the word.
            guard state.loading else { return }
            state.loading = false
            if lastError == nil {
                lastError = ErrorWording.backendStopped
                lastErrorLevel = .error
            }
            lookupSettled(wasLoading: true)
        default:
            break
        }
    }

    /// Shows a banner under the lookup in the panel and says it to VoiceOver: 3 s, 6 s
    /// for errors. (An announcement is not a banner: it is the panel's own message, and
    /// leaves the lookup and its banner alone; see `AppDelegate.announce`.)
    func show(banner text: String, level: NotificationLevel) {
        bannerDismissTask?.cancel()
        withAnimation(Motion.stateChange) { banner = BannerMessage(text: text, level: level) }
        speak(text)
        let duration = Self.bannerDuration(for: level)
        bannerDismissTask = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            await MainActor.run { withAnimation(Motion.stateChange) { self?.banner = nil } }
        }
    }

    static func bannerDuration(for level: NotificationLevel) -> Duration {
        level == .error ? .seconds(6) : .seconds(3)
    }

    // MARK: - VoiceOver

    /// What was last said to VoiceOver, newest last; read by the snapshot probes.
    @ObservationIgnored private(set) var spokenAnnouncements: [String] = []

    /// The panel is non-activating, so VoiceOver's cursor stays in the user's app and
    /// never reads it: results, banners and announcements are said instead.
    func speak(_ text: String) {
        guard !text.isEmpty else { return }
        spokenAnnouncements = Array((spokenAnnouncements + [text]).suffix(20))
        NSAccessibility.post(
            element: NSApp.mainWindow ?? NSApp as Any,
            notification: .announcementRequested,
            userInfo: [
                .announcement: text,
                .priority: NSAccessibilityPriorityLevel.high.rawValue,
            ]
        )
    }

    /// A lookup stopped loading: say what it found, once. A failure whose reason is
    /// already on screen as a banner was said with the banner.
    private func lookupSettled(wasLoading: Bool) {
        guard wasLoading, !state.loading, !state.originalText.isEmpty else { return }
        if let lastError, banner?.text == lastError { return }
        speak(PopupSpeech.summary(for: state, error: lastError))
    }

    // MARK: - Requests

    func refreshPing() async {
        ping = try? await client.send(IPCMethod.ping, as: PingInfo.self)
        if let ping { appleTranslationReady = ping.engines.appleTranslation }
    }

    /// The engine snapshot is cached for five minutes, so straight after a language pair
    /// finishes downloading the ping still reports it as merely supported and the setup
    /// stage keeps offering a download for a pair already on disk. This asks the backend
    /// to look again and answer in the same call.
    func refreshEngines() async {
        guard let engines = try? await client.send(
            IPCMethod.enginesRefresh, as: PingInfo.Engines.self
        ) else { return }
        ping?.engines = engines
        appleTranslationReady = engines.appleTranslation
    }

    /// Read the note type's fields, so a name that Anki does not have can be shown as
    /// wrong while the user is still looking at it, rather than failing at the moment a
    /// card is added.
    func loadModelFields() async {
        guard let answer = try? await client.send(
            IPCMethod.ankiModelFields, as: AnkiModelFields.self
        ) else {
            ankiModelFields = []
            ankiModelFieldsError = ErrorWording.backendNoAnswer
            return
        }
        ankiModelFields = answer.fields
        ankiModelFieldsError = answer.error
    }

    /// Configured names the note type does not have. Empty while nothing is known.
    var ankiFieldIssues: [AnkiFieldIssue] {
        AnkiFieldCheck.issues(
            configured: [
                settings.anki.fields.word,
                settings.anki.fields.translation,
                settings.anki.fields.exampleEn,
                settings.anki.fields.definitionsEn,
                settings.anki.fields.image,
            ],
            modelFields: ankiModelFields
        )
    }

    /// Whether the backend's settings have been read. Until then the panes hold defaults,
    /// and a change made to them could not be saved.
    var settingsLoaded: Bool { settingsSync.isLoaded }

    // MARK: - Open at login

    func refreshLoginItem() {
        loginItem = LoginItem.state
    }

    /// Turning it on asks the system for the registration; macOS may then want the user
    /// to approve it, which is a different state and not a failure.
    func setLoginItem(_ on: Bool) {
        do {
            if on { try LoginItem.enable() } else { try LoginItem.disable() }
            settingsProblems[.loginItem] = nil
        } catch {
            settingsProblems[.loginItem] = on
                ? "Couldn’t turn on opening at login: \(error.localizedDescription)"
                : "Couldn’t turn off opening at login: \(error.localizedDescription)"
        }
        // Ask the system what it now thinks rather than assuming the call decided it.
        refreshLoginItem()
    }

    // MARK: - Offline databases

    /// Only the app can ask for the 1.8 GB the offline sources need; until now the answer
    /// was "run a shell script", which is not something a setup stage can offer.
    func downloadDatabases() async {
        let start: DatabaseDownloadStart
        do {
            start = try await client.send(IPCMethod.dbDownload, as: DatabaseDownloadStart.self)
        } catch {
            settingsProblems[.databases] = "Couldn’t start the download. \(message(for: error))"
            return
        }
        settingsProblems[.databases] = nil
        guard start.started else {
            // Nothing missing: the ping was stale. Once it is fresh the row that offered
            // the download reads complete, which says it better than a message would.
            await refreshPing()
            return
        }
        databaseDownloads = start.files.reduce(into: [:]) { out, file in
            out[file] = DatabaseProgressEvent(file: file, state: .downloading)
        }
    }

    func cancelDatabaseDownload() async {
        _ = try? await client.send(IPCMethod.dbCancel)
    }

    private func apply(databaseProgress payload: DatabaseProgressEvent) {
        guard !payload.file.isEmpty else {
            // An empty file name is the whole operation ending, not one download.
            databaseDownloads = [:]
            if let error = payload.error { settingsProblems[.databases] = error }
            Task { await refreshPing() }
            return
        }
        databaseDownloads[payload.file] = payload
        switch payload.state {
        case .failed:
            settingsProblems[.databases] = payload.error ?? "\(payload.file) failed to download."
        case .done, .present:
            // Ask what the backend now sees rather than assuming the store is complete:
            // the other two files may still be arriving.
            Task { await refreshPing() }
        default:
            break
        }
        if databaseDownloads.values.allSatisfy({ $0.state == .done || $0.state == .present }) {
            databaseDownloads = [:]
        }
    }

    func translate(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        lastError = nil
        lastErrorLevel = .error
        phase = .begin
        withAnimation(Motion.stateChange) {
            state = ViewState(original: trimmed, originalRaw: text, loading: true)
        }
        do {
            let response = try await client.send(IPCMethod.translate, params: ["text": text], as: TranslateResponse.self)
            activeRequestId = response.requestId
            let wasLoading = state.loading
            withAnimation(Motion.stateChange) { state = response.state }
            lookupSettled(wasLoading: wasLoading)
        } catch {
            // Said once, as the body of the panel; a banner repeating it under the same
            // words would only say it twice.
            state.loading = false
            lastError = message(for: error)
            lastErrorLevel = .error
            lookupSettled(wasLoading: true)
        }
    }

    func cancel() async {
        _ = try? await client.send(IPCMethod.cancel)
    }

    func closeSession() async {
        _ = try? await client.send(IPCMethod.close)
        closedSessions += 1
    }

    func refreshExamples() async {
        guard state.canRefreshExamples, !state.refreshingExamples else { return }
        state.refreshingExamples = true
        do {
            let response = try await client.send(IPCMethod.examplesRefresh, as: ExamplesRefreshResponse.self)
            withAnimation(Motion.stateChange) { state = response.state }
            if !response.changed {
                // "Other" only when there were examples on screen to replace.
                let found = response.state.examples.isEmpty ? "No examples found." : "No other examples found."
                show(banner: found, level: .info)
            }
        } catch {
            state.refreshingExamples = false
            show(banner: message(for: error), level: .error)
        }
    }

    func copyAll() async {
        do {
            let response = try await client.send(IPCMethod.copyAll, as: CopyAllResponse.self)
            SelectionCapture.writeToPasteboard(response.text)
            show(banner: "Copied.", level: .success)
        } catch {
            show(banner: message(for: error), level: .error)
        }
    }

    /// Reloads the history. A failure is kept in `historyLoadError` for the History window
    /// to show: a banner would go to the popup, which is not on screen.
    @discardableResult
    func loadHistory() async -> Bool {
        do {
            history = try await client.send(IPCMethod.historyList, as: HistoryListResponse.self).items
            historyLoadError = nil
            return true
        } catch {
            historyLoadError = message(for: error)
            return false
        }
    }

    /// Makes a history entry the current lookup. False when the backend refused; the
    /// reason is in `historyOpenFailure` and the state still holds the previous lookup.
    func selectHistory(_ entryId: Int) async -> Bool {
        do {
            let response = try await client.send(
                IPCMethod.historySelect, params: ["entry_id": entryId], as: TranslateResponse.self
            )
            activeRequestId = response.requestId
            withAnimation(Motion.stateChange) { state = response.state }
            return true
        } catch {
            let word = history.first { $0.entryId == entryId }?.text ?? ""
            historyOpenFailure = HistoryOpenFailure(word: word, message: message(for: error))
            return false
        }
    }

    // MARK: - Anki

    func refreshAnkiStatus() async {
        guard let status = try? await client.send(IPCMethod.ankiStatus, as: AnkiStatus.self) else { return }
        ankiStatus = status
    }

    func loadDecks() async {
        do {
            let response = try await client.send(IPCMethod.ankiDecks, as: AnkiDecksResponse.self)
            ankiDecks = response.decks
            // "Anki isn't running" is said by the Connection row already.
            let error = response.error.flatMap { $0.isEmpty ? nil : $0 }
            settingsProblems[.anki] = ankiStatus.available ? error : nil
        } catch {
            settingsProblems[.anki] = message(for: error)
        }
    }

    /// Asks Anki for its note types. A backend without the method leaves the list empty
    /// and says so through `ankiNoteTypesSupported`.
    func loadNoteTypes() async {
        do {
            let response = try await client.send(IPCMethod.ankiModelNames, as: AnkiModelNames.self)
            ankiNoteTypesSupported = true
            ankiNoteTypes = response.models
        } catch let error as IPCError where error.code == "unknown_method" {
            ankiNoteTypesSupported = false
            ankiNoteTypes = []
        } catch {
            ankiNoteTypes = []
        }
    }

    /// Makes `name` the note type cards are added with: saved at once rather than after the
    /// usual pause, because the field list that follows is the backend's for its saved
    /// note type.
    func selectNoteType(_ name: String) async {
        // A pop-up sets it already, so its title changes with the click.
        if settings.anki.model != name { settings.anki.model = name }
        await saveSettingsNow()
        async let fields: Void = loadModelFields()
        async let status: Void = refreshAnkiStatus()
        _ = await (fields, status)
    }

    func selectDeck(_ deck: String) async {
        guard let result = await runAction(IPCMethod.ankiSelectDeck, params: ["deck": deck]) else { return }
        // The backend answers with a message whatever happened; the deck it reports says
        // whether the choice took.
        settingsProblems[.anki] = result.deckName == deck || result.message.isEmpty ? nil : result.message
    }

    func createModel() async {
        guard let result = await runAction(IPCMethod.ankiCreateModel) else { return }
        let ready = result.modelStatus?.localizedCaseInsensitiveContains("ready") ?? false
        settingsProblems[.anki] = ready || result.message.isEmpty ? nil : result.message
    }

    /// Nil when the request itself failed; that failure is already recorded for the Anki
    /// pane.
    private func runAction(_ method: String, params: [String: Any] = [:]) async -> ActionResult? {
        do {
            let result = try await client.send(method, params: params, as: ActionResult.self)
            apply(result)
            return result
        } catch {
            settingsProblems[.anki] = message(for: error)
            return nil
        }
    }

    private func apply(_ result: ActionResult) {
        if let model = result.modelStatus { ankiStatus.modelStatus = model }
        if let deck = result.deckStatus { ankiStatus.deckStatus = deck }
        if let name = result.deckName { ankiStatus.deckName = name }
    }

    /// Asks the backend to prepare the note for the current lookup. Only the newest call
    /// counts: a preparation for a lookup that has since been replaced may answer late (or,
    /// once the backend has dropped it, only by timing out), and it must neither replace
    /// the newer preview nor raise a banner about a word nobody is adding any more.
    func prepareUpsert() async {
        upsertPreparation += 1
        let preparation = upsertPreparation
        isPreparingUpsert = true
        defer { if preparation == upsertPreparation { isPreparingUpsert = false } }
        do {
            let response = try await client.send(IPCMethod.ankiPrepareUpsert, as: UpsertPreviewResponse.self)
            guard preparation == upsertPreparation else { return }
            upsertPreview = response.preview
        } catch {
            guard preparation == upsertPreparation else { return }
            upsertPreview = nil
            show(banner: message(for: error), level: .error)
        }
    }

    /// Forgets any preparation still in flight, so its answer is ignored.
    func abandonUpsertPreparation() {
        upsertPreparation += 1
        isPreparingUpsert = false
        upsertPreview = nil
    }

    func applyUpsert(_ decision: UpsertDecision) async -> Bool {
        do {
            let payload = try decision.jsonObject()
            let outcome = try await client.send(
                IPCMethod.ankiApplyUpsert, params: ["decision": payload], as: UpsertOutcome.self
            )
            if outcome.isSuccess {
                show(banner: outcome.message, level: .success)
            } else {
                show(banner: await explain(ankiFailure: outcome.message), level: .warning)
            }
            await refreshAnkiStatus()
            return outcome.isSuccess
        } catch {
            show(banner: message(for: error), level: .error)
            return false
        }
    }

    /// Anki's own words plus what they mean here.
    ///
    /// A mistyped field name makes Anki answer "cannot create note because it is empty",
    /// which sends the user looking at the card — the note is not empty, the name is
    /// wrong. The app knows both halves and can say so, so it does.
    private func explain(ankiFailure message: String) async -> String {
        // The field list may never have been read: nobody has to open the mapping
        // section for this to be the cause.
        if ankiModelFields.isEmpty, ankiModelFieldsError == nil { await loadModelFields() }
        return AnkiFieldCheck.explain(failure: message, issues: ankiFieldIssues)
    }

    // MARK: - Settings

    /// How long a change waits for the next one before it is saved: long enough that
    /// typing a field name is one save, short enough to feel immediate.
    private static let settingsSaveDelay: Duration = .milliseconds(400)

    func refreshSettings() async {
        guard let data = try? await client.send(IPCMethod.settingsGet),
              let loaded = try? BackendSettings.decode(from: data)
        else { return }
        // A change still waiting to be saved, or one the backend refused, is newer than
        // what the backend has; it wins. A refused one is sent again now.
        let saving = pendingSettingsSave != nil || settingsSavesInFlight > 0
        switch settingsSync.loaded(loaded, local: settings, saveInProgress: saving) {
        case .adopt:
            // What the backend holds is by definition saved, so taking it must not
            // schedule a save of its own.
            if settings != loaded { settings = loaded }
        case .keepLocal:
            break
        case .retrySave:
            await saveSettings()
        }
    }

    /// Sends a waiting change now instead of after the pause.
    func saveSettingsNow() async {
        pendingSettingsSave?.cancel()
        pendingSettingsSave = nil
        guard settingsSync.needsSave(settings) else { return }
        await saveSettings()
    }

    /// Called on every change to `settings`. Loading from the backend does not count as a
    /// change: `settingsSync` knows what the backend has, and equal values are not sent.
    private func scheduleSettingsSave() {
        // Before the first load `settings` holds defaults, and saving them would overwrite
        // the user's real configuration. The panes are disabled until then.
        guard settingsSync.isLoaded else { return }
        guard settingsSync.needsSave(settings) else {
            pendingSettingsSave?.cancel()
            pendingSettingsSave = nil
            // Changed back to what the backend holds: nothing is unsaved any more.
            if let synced = settingsSync.synced, settingsSync.saveFailed {
                settingsSync.saved(synced)
                settingsProblems[.save] = nil
            }
            return
        }
        pendingSettingsSave?.cancel()
        pendingSettingsSave = Task { [weak self] in
            try? await Task.sleep(for: Self.settingsSaveDelay)
            guard !Task.isCancelled, let self else { return }
            self.pendingSettingsSave = nil
            await self.saveSettings()
        }
    }

    /// Sends the current settings. Silent when it works — the change is visible where it
    /// was made — and says so only when it did not.
    func saveSettings() async {
        let sent = settings
        settingsSavesInFlight += 1
        defer { settingsSavesInFlight -= 1 }
        do {
            let payload = try sent.jsonObject()
            let result = try await client.send(IPCMethod.settingsSave, params: ["config": payload], as: ActionResult.self)
            settingsSync.saved(sent)
            settingsProblems[.save] = nil
            apply(result)
            // The engines report which sources are on; setup reads it from there.
            await refreshPing()
        } catch {
            settingsSync.saveDidFail()
            settingsProblems[.save] = "Changes weren’t saved: \(message(for: error)) They are sent again when the backend is back."
        }
    }

    /// Records a new shortcut, or nil for none.
    func updateHotKey(_ combo: KeyCombo?) {
        hotKey = combo
        UserDefaults.standard.set(combo?.storageString ?? Self.noHotKey, forKey: "hotKey")
    }

    func loadStoredHotKey() {
        guard let raw = UserDefaults.standard.string(forKey: "hotKey") else { return }
        if raw == Self.noHotKey {
            hotKey = nil
        } else if let combo = KeyCombo(storageString: raw) {
            hotKey = combo
        }
    }

    /// Stored for a shortcut the user cleared, so the default does not come back.
    private static let noHotKey = "none"

    func refreshAccessibilityTrust() {
        accessibilityTrusted = SelectionCapture.isTrusted
        // Written so scripts can read it: asking from a script answers for the script's
        // own parent process, never for this app.
        UserDefaults.standard.set(accessibilityTrusted, forKey: "accessibilityTrusted")
    }

    /// The one place a failed request becomes a sentence for the user (see
    /// `ErrorWording`). The raw error goes to the log, where it is useful.
    func message(for error: Error) -> String {
        if let ipc = error as? IPCError {
            NSLog("[translator] request failed: %@ %@", ipc.code, ipc.message)
            return ErrorWording.sentence(code: ipc.code, message: ipc.message)
        }
        NSLog("[translator] request failed: %@", String(describing: error))
        if error is DecodingError { return "Translator’s backend sent an answer the app couldn’t read." }
        return error.localizedDescription
    }
}
