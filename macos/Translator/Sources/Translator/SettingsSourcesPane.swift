import SwiftUI
import Translation
import TranslatorCore

/// Sources: which of them may answer a lookup, and the language pair Apple Translation
/// needs to answer offline.
///
/// Switching one off is a real question — is the network worth the wait, is a dictionary
/// entry too much — so each checkbox says in one line what the source contributes.
struct SourcesSettingsPane: View {
    @Bindable var model: AppModel

    var body: some View {
        SettingsPane {
            SettingsSection(title: "Sources") {
                SettingsToggle(
                    title: "Apple Dictionary",
                    description: "Senses, pronunciation and examples, offline.",
                    isOn: $model.settings.sources.appleDictionary
                )
                SettingsToggle(
                    title: "Apple Translation",
                    description: "Phrases and sentences, offline once the language pair is here.",
                    isOn: $model.settings.sources.appleTranslation
                )
                SettingsToggle(
                    title: "Google",
                    description: "Over the network; the fallback for rarer phrasing.",
                    isOn: $model.settings.sources.google
                )
                SettingsToggle(
                    title: "Cambridge",
                    description: "Over the network; the slowest source.",
                    isOn: $model.settings.sources.cambridge
                )
                SettingsToggle(
                    title: "Offline examples",
                    description: "The example sentence corpus on this Mac.",
                    isOn: $model.settings.sources.offlineExamples
                )
                SettingsToggle(
                    title: "Definitions pack",
                    description: "English definitions, offline.",
                    isOn: $model.settings.sources.definitionsPack
                )
            }

            SettingsDivider()

            SettingsSection(title: "Translation") {
                LanguagePairControl(model: model)
            }
        }
    }
}

/// The state of the Apple Translation language pair and, when Apple offers it, the button
/// that downloads it. The system download sheet only appears from a SwiftUI
/// `translationTask`, so the download lives in this view.
private struct LanguagePairControl: View {
    @Bindable var model: AppModel

    @State private var configuration: TranslationSession.Configuration?
    @State private var isDownloading = false
    @State private var failure: String?

    private var step: SetupStep? {
        model.setupPlan.steps.first { $0.id == .translationPair }
    }

    private var pairName: String {
        let languages = model.settings.languages
        // In the app's own language, not the Mac's: the rest of the window is English.
        let english = Locale(identifier: "en")
        let name = { (code: String) in
            english.localizedString(forLanguageCode: code) ?? code.uppercased()
        }
        return "\(name(languages.source)) → \(name(languages.target))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SettingsStatus(level: level, title: pairName, note: note)
            SettingsStatusDetail {
                if step?.action == .downloadLanguagePair {
                    HStack(spacing: 8) {
                        Button("Download…", action: download)
                            .disabled(isDownloading)
                        if isDownloading { ProgressView().controlSize(.small) }
                    }
                }
            }
        }
        .translationTask(configuration) { session in
            do {
                try await session.prepareTranslation()
                await MainActor.run {
                    isDownloading = false
                    configuration = nil
                }
                // The engine snapshot is cached for five minutes; without this the pane
                // would keep offering a download for the pair just installed.
                await model.refreshEngines()
            } catch {
                await MainActor.run {
                    failure = "The download didn’t finish: \(error.localizedDescription)"
                    isDownloading = false
                    configuration = nil
                }
            }
        }
    }

    private var level: SettingsStatusLevel {
        if isDownloading { return .working }
        if failure != nil { return .error }
        switch step?.state {
        case .done: return .ok
        case .actionNeeded: return .warning
        case .waiting, .switchedOff, .none: return .unknown
        }
    }

    private var note: String? {
        if let failure { return failure }
        guard let step else { return nil }
        switch step.state {
        case .done:
            return "Language pair installed. Phrases translate without the network."
        case .switchedOff:
            return "Not used while Apple Translation is off."
        case .actionNeeded, .waiting:
            return step.detail
        }
    }

    private func download() {
        failure = nil
        isDownloading = true
        configuration = TranslationSession.Configuration(
            source: Locale.Language(identifier: model.settings.languages.source),
            target: Locale.Language(identifier: model.settings.languages.target)
        )
    }
}
