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

    var body: some View {
        HStack(alignment: alignment) {
            Text(title.isEmpty ? "" : "\(title):")
                .font(.system(size: 13))
                .fixedSize()
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(key: SettingsLabelWidthKey.self, value: proxy.size.width)
                    }
                }
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
struct SettingsToggle: View {
    let title: String
    var description: String?
    @Binding var isOn: Bool

    static let style = CheckboxToggleStyle()

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let description {
                    SettingsNote(description)
                }
            }
        }
        .toggleStyle(Self.style)
    }
}

/// Secondary explanatory text under a control, in the small system size.
struct SettingsNote: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
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
