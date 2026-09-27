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
    var lastError: String?

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

    private let client: IPCClient
    /// The settings the backend is known to hold: loaded from it, or saved to it. Nil
    /// until the first load.
    @ObservationIgnored private var syncedSettings: BackendSettings?
    /// The debounced save of a change, while it waits.
    @ObservationIgnored private var pendingSettingsSave: Task<Void, Never>?
    /// Saves sent and not answered yet; a load meanwhile would bring back the old values.
    @ObservationIgnored private var settingsSavesInFlight = 0
    private var bannerDismissTask: Task<Void, Never>?
    /// The last warning the backend sent, so an error phase can say why instead of
    /// "Translation failed."
    private var pendingNotice: String?

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
            withAnimation(Motion.stateChange) { state = payload.state }
            // The backend names the reason in a notification just before it reports the
            // error — "Every translation source is switched off." is not a failure to
            // retry, and calling it one sends the user looking for a fault.
            if payload.phase == .error { lastError = pendingNotice ?? "Translation failed." }
            pendingNotice = nil
        case IPCEventName.notification:
            guard let payload = try? event.decode(NotificationEvent.self) else { return }
            if payload.level != .info { pendingNotice = payload.message }
            show(banner: payload.message, level: payload.level)
        case IPCEventName.dbProgress:
            guard let payload = try? event.decode(DatabaseProgressEvent.self) else { return }
            apply(databaseProgress: payload)
        case IPCEventName.ankiAvailability:
            guard let payload = try? event.decode(AnkiAvailabilityEvent.self) else { return }
            ankiStatus.available = payload.available
        case IPCEventName.disconnected:
            state.loading = false
        default:
            break
        }
    }

    /// Drop whatever the popup was showing, so a bare message is not read as a result
    /// belonging to the previous lookup.
    func clearForAnnouncement() {
        state = ViewState()
        lastError = nil
    }

    func show(banner text: String, level: NotificationLevel) {
        bannerDismissTask?.cancel()
        withAnimation(Motion.stateChange) { banner = BannerMessage(text: text, level: level) }
        bannerDismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(level == .error ? 6 : 3))
            guard !Task.isCancelled else { return }
            await MainActor.run { withAnimation(Motion.stateChange) { self?.banner = nil } }
        }
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
            ankiModelFieldsError = "The backend did not answer."
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

    // MARK: - Open at login

    func refreshLoginItem() {
        loginItem = LoginItem.state
    }

    /// Turning it on asks the system for the registration; macOS may then want the user
    /// to approve it, which is a different state and not a failure.
    func setLoginItem(_ on: Bool) {
        do {
            if on { try LoginItem.enable() } else { try LoginItem.disable() }
        } catch {
            show(
                banner: on
                    ? "Could not turn on opening at login: \(error.localizedDescription)"
                    : "Could not turn off opening at login: \(error.localizedDescription)",
                level: .error
            )
        }
        // Ask the system what it now thinks rather than assuming the call decided it.
        refreshLoginItem()
    }

    // MARK: - Offline databases

    /// Only the app can ask for the 1.8 GB the offline sources need; until now the answer
    /// was "run a shell script", which is not something a setup stage can offer.
    func downloadDatabases() async {
        guard let start = try? await client.send(
            IPCMethod.dbDownload, as: DatabaseDownloadStart.self
        ) else {
            show(banner: "Could not start the download.", level: .error)
            return
        }
        guard start.started else {
            // Nothing missing: the button is safe to press and says so rather than
            // pretending to work.
            await refreshPing()
            show(banner: "The offline databases are already complete.", level: .info)
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
            if let error = payload.error { show(banner: error, level: .error) }
            Task { await refreshPing() }
            return
        }
        databaseDownloads[payload.file] = payload
        switch payload.state {
        case .failed:
            show(banner: payload.error ?? "\(payload.file) failed to download.", level: .error)
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
        phase = .begin
        withAnimation(Motion.stateChange) {
            state = ViewState(original: trimmed, originalRaw: text, loading: true)
        }
        do {
            let response = try await client.send(IPCMethod.translate, params: ["text": text], as: TranslateResponse.self)
            activeRequestId = response.requestId
            withAnimation(Motion.stateChange) { state = response.state }
        } catch {
            state.loading = false
            lastError = message(for: error)
            show(banner: message(for: error), level: .error)
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
            if !response.changed { show(banner: "No other examples found.", level: .info) }
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
            if let error = response.error, !error.isEmpty { show(banner: error, level: .warning) }
        } catch {
            show(banner: message(for: error), level: .error)
        }
    }

    func selectDeck(_ deck: String) async {
        await runAction(IPCMethod.ankiSelectDeck, params: ["deck": deck])
    }

    func createModel() async {
        await runAction(IPCMethod.ankiCreateModel)
    }

    private func runAction(_ method: String, params: [String: Any] = [:]) async {
        do {
            let result = try await client.send(method, params: params, as: ActionResult.self)
            apply(result)
            if !result.message.isEmpty { show(banner: result.message, level: .success) }
        } catch {
            show(banner: message(for: error), level: .error)
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
        // A change still waiting to be saved is newer than what the backend has; it wins,
        // and the save that is about to run brings the backend up to date.
        guard pendingSettingsSave == nil, settingsSavesInFlight == 0 else { return }
        // What the backend holds is by definition saved, so taking it must not schedule a
        // save of its own.
        syncedSettings = loaded
        if settings != loaded { settings = loaded }
    }

    /// Called on every change to `settings`. Loading from the backend does not count as a
    /// change: `syncedSettings` is what the backend has, and equal values are not sent.
    private func scheduleSettingsSave() {
        // Before the first load `settings` holds defaults, and saving them would overwrite
        // the user's real configuration.
        guard let synced = syncedSettings else { return }
        guard settings != synced else {
            pendingSettingsSave?.cancel()
            pendingSettingsSave = nil
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
            syncedSettings = sent
            apply(result)
            // The engines report which sources are on; setup reads it from there.
            await refreshPing()
        } catch {
            show(banner: "Settings weren’t saved: \(message(for: error))", level: .error)
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

    private func message(for error: Error) -> String {
        if let ipc = error as? IPCError { return ipc.message.isEmpty ? ipc.code : ipc.message }
        return error.localizedDescription
    }
}
