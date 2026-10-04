import SwiftUI

// The layout of a Mac settings pane, as Maccy's panes and sindresorhus/Settings draw it:
// a column of right-aligned labels ending in a colon, and to their right a column of
// controls whose leading edges all line up. Every on/off control in that column is the
// same `SettingsToggle`, so a checkbox sits at the same x whatever its text says.

/// One pane's content: fixed width, the standard pane margins, the shared label column.
struct SettingsPane<Content: View>: View {
    var contentWidth: CGFloat = 450
    @ViewBuilder var content: Content

    @State private var labelWidth: CGFloat = 0

    var body: some View {
        VStack(alignment: .settingsLabel, spacing: 14) {
            content
        }
        .onPreferenceChange(SettingsLabelWidthKey.self) { labelWidth = $0 }
        .environment(\.settingsLabelWidth, labelWidth)
        .frame(width: contentWidth, alignment: .leading)
        .padding(.vertical, 20)
        .padding(.horizontal, 30)
    }
}

/// A labelled row of the pane: `"Startup:"` on the left, its controls stacked on the right.
struct SettingsSection<Content: View>: View {
    let title: String
    var alignment: VerticalAlignment = .firstTextBaseline
    @ViewBuilder var content: Content

    @Environment(\.settingsLabelWidth) private var labelWidth
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        HStack(alignment: alignment) {
            Text(title.isEmpty ? "" : "\(title):")
                .font(.system(size: 13))
                // The label of controls that are all disabled dims with them, as AppKit's do.
                .foregroundStyle(isEnabled ? .primary : .tertiary)
                .fixedSize()
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(key: SettingsLabelWidthKey.self, value: proxy.size.width)
                    }
                }
                // Every label takes the widest label's width. Aligning on the guide alone
                // shifts a row with a shorter label to the right after it was laid out at
                // the full pane width, so wrapping text in it ran past the pane's edge by
                // the difference between the two labels.
                .frame(minWidth: labelWidth, alignment: .trailing)
                .alignmentGuide(.settingsLabel) { $0[.trailing] }
            VStack(alignment: .leading, spacing: 6) {
                content
            }
            Spacer(minLength: 0)
        }
    }
}

/// A divider that spans the control column, between groups of sections.
struct SettingsDivider: View {
    @Environment(\.settingsLabelWidth) private var labelWidth

    var body: some View {
        Divider()
            .padding(.vertical, 4)
            .alignmentGuide(.settingsLabel) { $0[.leading] + labelWidth }
    }
}

/// The one on/off control of every pane.
///
/// The control leads and its text follows, so the control's position never depends on
/// how long the text is. The style is chosen here and nowhere else.
///
/// The text is a sibling of the control rather than the Toggle's own label: a checkbox
/// Toggle lays its label out at the label's ideal width, so a title or description that
/// had to wrap ran a few points past the pane. As a sibling in an HStack it gets exactly
/// the width that is left and wraps inside it; a click on it still flips the control.
struct SettingsToggle<Detail: View>: View {
    let title: String
    var description: String?
    @Binding var isOn: Bool
    /// Anything that belongs to this setting (a state, a button), under its text.
    @ViewBuilder var detail: Detail

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Toggle(title, isOn: $isOn)
                .toggleStyle(SettingsToggleStyle.current)
                .labelsHidden()
            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(isEnabled ? .primary : .tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        // The Toggle already carries the title; reading it twice helps nobody.
                        .accessibilityHidden(true)
                    if let description {
                        // Read as the text after the checkbox, as System Settings' footnotes
                        // are. A hint is spoken late, or never with hints turned off, and a
                        // description can be content (the note Add to Anki would update).
                        SettingsNote(description)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
                .onTapGesture { if isEnabled { isOn.toggle() } }
                detail
            }
        }
    }
}

extension SettingsToggle where Detail == EmptyView {
    init(title: String, description: String? = nil, isOn: Binding<Bool>) {
        self.init(title: title, description: description, isOn: isOn) { EmptyView() }
    }
}

/// The style of every on/off control in the app's settings-style windows.
enum SettingsToggleStyle {
    /// The one line to change for switches instead of checkboxes: `SwitchToggleStyle()`.
    static let current = CheckboxToggleStyle()
}

/// How a status row reads: one system symbol per state, never colour alone.
enum SettingsStatusLevel {
    case ok
    case warning
    case error
    case unknown
    /// Work under way: a small spinner in the symbol's place.
    case working

    fileprivate var symbol: String {
        switch self {
        case .ok: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        case .unknown, .working: return "circle.dashed"
        }
    }

    /// What VoiceOver says for the symbol, which it cannot see.
    var spokenName: String {
        switch self {
        case .ok: return "Available"
        case .warning: return "Needs attention"
        case .error: return "Error"
        case .unknown: return "Unknown"
        case .working: return "In progress"
        }
    }

    fileprivate var tint: Color {
        switch self {
        case .ok: return .green
        case .warning: return .yellow
        case .error: return .red
        case .unknown, .working: return .secondary
        }
    }
}

/// A state, said once: a status symbol, a title in the body style, and an optional note
/// under the title (aligned with the title, not with the symbol).
struct SettingsStatus: View {
    let level: SettingsStatusLevel
    let title: String
    var note: String?

    /// Wide enough for any of the symbols, so the titles of neighbouring rows line up.
    static let symbolWidth: CGFloat = 16

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Group {
                if level == .working {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: Self.symbolWidth, height: Self.symbolWidth)
                        .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 3 }
                } else {
                    Image(systemName: level.symbol)
                        .foregroundStyle(level.tint)
                        .frame(width: Self.symbolWidth)
                }
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fixedSize(horizontal: false, vertical: true)
                if let note {
                    SettingsNote(note)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        // The symbol is hidden from VoiceOver; the state it shows is said instead.
        .accessibilityLabel(title)
        .accessibilityValue(
            [level.spokenName, note?.trimmingCharacters(in: .whitespacesAndNewlines)]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: ". ")
        )
    }
}

/// Indents content under a `SettingsStatus` title, e.g. the one button of a status row.
struct SettingsStatusDetail<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            content
        }
        .padding(.leading, SettingsStatus.symbolWidth + 6)
    }
}

/// Secondary explanatory text under a control, in the small system size. Under a
/// disabled control it dims further, so it never reads stronger than the title above it.
struct SettingsNote: View {
    let text: String

    @Environment(\.isEnabled) private var isEnabled

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(isEnabled ? .secondary : .tertiary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// The name of one row in a grid of controls (Anki's fields, Add to Anki's merge rows).
/// A view of its own so that it reads `isEnabled` where it is drawn: a function of the
/// parent would read the parent's environment, not that of the disabled rows.
struct SettingsRowLabel: View {
    let text: String

    @Environment(\.isEnabled) private var isEnabled

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .foregroundStyle(isEnabled ? .primary : .tertiary)
    }
}

private struct SettingsLabelWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct SettingsLabelWidthEnvironmentKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    fileprivate var settingsLabelWidth: CGFloat {
        get { self[SettingsLabelWidthEnvironmentKey.self] }
        set { self[SettingsLabelWidthEnvironmentKey.self] = newValue }
    }
}

extension HorizontalAlignment {
    private enum SettingsLabel: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat {
            context[HorizontalAlignment.leading]
        }
    }

    /// Where the label column ends and the control column begins.
    static let settingsLabel = HorizontalAlignment(SettingsLabel.self)
}
