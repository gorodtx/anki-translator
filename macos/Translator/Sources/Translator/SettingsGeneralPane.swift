import SwiftUI
import TranslatorCore

/// General: what setup still needs (only while it needs something), the shortcut, and
/// opening at login.
struct GeneralSettingsPane: View {
    @Bindable var model: AppModel
    var applyHotKey: (KeyCombo?) -> Void
    var suspendHotKey: (Bool) -> Void

    var body: some View {
        SettingsPane {
            if !model.setupPlan.checklist.isEmpty {
                SettingsSection(title: "Setup") {
                    SetupChecklist(model: model) {
                        ShortcutRecorderField.current?.beginRecording()
                    }
                }
                SettingsDivider()
            }

            SettingsSection(title: "Shortcut") {
                ShortcutRecorder(
                    combo: model.hotKey,
                    onChange: { combo in
                        model.updateHotKey(combo)
                        applyHotKey(combo)
                    },
                    onRecordingChange: suspendHotKey
                )
                SettingsNote(
                    model.hotKey == nil
                        ? "No shortcut. Translate is still in the Services menu."
                        : "Also available in the Services menu."
                )
            }

            SettingsSection(title: "Startup") {
                // Read from the system every time the window becomes key: the user can
                // change it in System Settings and the app is never told.
                SettingsToggle(
                    title: "Open at login",
                    description: "The shortcut works only while the app is open.",
                    isOn: Binding(
                        get: { model.loginItem.isOn },
                        set: { model.setLoginItem($0) }
                    )
                ) {
                    loginItemState
                }
            }
        }
    }

    /// Registered already but not approved, or a state this build does not know: said
    /// under the checkbox's text, with the one button that helps.
    @ViewBuilder
    private var loginItemState: some View {
        if let problem = model.settingsProblems[.loginItem] {
            SettingsStatus(level: .error, title: problem)
        }
        switch model.loginItem {
        case .requiresApproval:
            SettingsStatus(level: .warning, title: "Waiting for your approval in System Settings.")
            Button("Open Login Items…") { LoginItem.openSettings() }
        case .unavailable:
            SettingsStatus(level: .unknown, title: "The system reported a state this version does not understand.")
        case .enabled, .notRegistered:
            EmptyView()
        }
    }
}
