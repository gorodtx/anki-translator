import SwiftUI
import TranslatorCore

/// The content of the translation panel: a dictionary entry laid out like a system
/// popover, with Maccy's menu-like footer.
///
/// It never sizes its window. It reports its natural height — header + body + banner +
/// footer, each measured at the width it is given — and the panel controller decides the
/// frame. The body is the only flexible part: when the panel is capped, it scrolls inside
/// its own clipped region and nothing can draw over the header or the footer.
struct TranslationPopupView: View {
    @Bindable var model: AppModel
    var chrome: PopupChrome
    var onNaturalHeight: (CGFloat) -> Void
    var onOpenAnki: () -> Void

    @State private var parts = HeightParts()
    /// The body is scrolled away from its top: a hairline separates it from the header,
    /// as a title bar gains its separator once content moves under it.
    @State private var scrolled = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            measured(\.header) { header }
                .overlay(alignment: .bottom) {
                    if scrolled {
                        Divider().padding(.horizontal, PopupMetrics.rowInset + PopupMetrics.separatorInset)
                    }
                }
            ScrollView(.vertical) {
                measured(\.body) { content }
            }
            .scrollBounceBehavior(.basedOnSize)
            // Only a capped body scrolls; otherwise an indicator would flash while the
            // panel grows into its height.
            .scrollIndicators(chrome.bodyScrolls ? .automatic : .never)
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top > 0.5
            } action: { _, isScrolled in
                scrolled = isScrolled
            }
            .contentMargins(.vertical, PopupMetrics.indicatorInset, for: .scrollIndicators)
            // A new lookup starts at the top, not where the last one was scrolled to.
            .id(query)
            measured(\.bottom) { bottom }
        }
        // Exactly the panel's size, top-anchored. Between new content and the frame change
        // that follows it on the next turn, content taller than the panel must hang from
        // the header, not be centred on the old frame.
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .top)
        .clipped()
        // The bare background moves the panel; text on top of it selects instead.
        .background { WindowDragArea() }
        .ignoresSafeArea()
        // The model animates its state changes; the panel does not cross-fade text.
        .transaction { $0.animation = nil }
    }

    // MARK: - Measuring

    /// Wraps a fixed-height part and reports its natural height. The wrapper always
    /// exists, so a part that empties reports zero instead of keeping its last value.
    private func measured(
        _ part: ReferenceWritableKeyPath<HeightParts, CGFloat>,
        @ViewBuilder _ content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                guard abs(parts[keyPath: part] - height) > 0.25 else { return }
                parts[keyPath: part] = height
                onNaturalHeight(parts.total)
            }
    }

    // MARK: - State

    private var state: ViewState { model.state }
    private var query: String { state.originalText.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isSentence: Bool { PopupLayout.isSentence(query) }

    private var hasResult: Bool { PopupContent.hasResult(state) }

    /// A finished lookup that found nothing (as opposed to an announcement, which has no query).
    private var isNoResult: Bool { !query.isEmpty && !state.loading && !hasResult }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        if !query.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if isSentence {
                        Text(query)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineLimit(4)
                            .truncationMode(.tail)
                    } else {
                        Text(query)
                            .font(.title2.weight(.semibold))
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                    if state.loading {
                        ProgressView()
                            .controlSize(.small)
                            // Sit on the first line, centred on its x-height.
                            .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 4 }
                            .accessibilityLabel("Translating")
                    }
                }
                if let pronunciation {
                    Text(pronunciation)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .textSelection(.enabled)
            .padding(.horizontal, PopupMetrics.textInset)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
    }

    private var pronunciation: String? {
        guard !isSentence, let apple = state.apple else { return nil }
        var parts: [String] = []
        if !apple.ipaUk.isEmpty { parts.append("BrE \(apple.ipaUk)") }
        if !apple.ipaUs.isEmpty { parts.append("AmE \(apple.ipaUs)") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    // MARK: - Body

    @ViewBuilder
    private var content: some View {
        if hasResult {
            VStack(alignment: .leading, spacing: 0) {
                if state.hasTranslation {
                    Text(state.translationText)
                        .font(.title3)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let apple = state.apple, !apple.groupedEntries.isEmpty {
                    SectionHeader("Dictionary", first: !state.hasTranslation)
                    dictionary(apple)
                }
                if !state.definitionsItems.isEmpty {
                    SectionHeader("Definitions", first: !state.hasTranslation && !(state.apple?.groupedEntries.isEmpty == false))
                    definitions
                }
                if !state.examples.isEmpty {
                    SectionHeader("Examples", first: false)
                    examples
                }
            }
            .textSelection(.enabled)
            .padding(.horizontal, PopupMetrics.textInset)
            .padding(.bottom, 12)
        } else if isNoResult {
            Text(model.lastError ?? "No translation for “\(query)”.")
                .font(.body)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .padding(.horizontal, PopupMetrics.textInset)
                .padding(.bottom, 12)
        }
    }

    private func dictionary(_ apple: AppleLexical) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(apple.groupedEntries.enumerated()), id: \.offset) { groupIndex, entry in
                if !entry.pos.isEmpty {
                    Text(entry.pos)
                        .font(.callout.italic())
                        .foregroundStyle(.secondary)
                        .padding(.top, groupIndex == 0 ? 2 : 10)
                        .padding(.bottom, 4)
                }
                VStack(alignment: .leading, spacing: PopupMetrics.rowGap) {
                    ForEach(Array(entry.senses.enumerated()), id: \.offset) { _, sense in
                        senseRow(sense)
                    }
                }
                .padding(.top, entry.pos.isEmpty && groupIndex > 0 ? PopupMetrics.rowGap : 0)
            }
        }
    }

    private func senseRow(_ sense: AppleSense) -> some View {
        NumberedRow(number: sense.index) {
            VStack(alignment: .leading, spacing: 2) {
                if !sense.translation.isEmpty {
                    Text(sense.translation)
                        .font(.body)
                        .foregroundStyle(.primary)
                }
                if !sense.label.isEmpty {
                    Text("(\(sense.label))")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                ForEach(Array(sense.examples.enumerated()), id: \.offset) { _, pair in
                    Text(pair.ru.isEmpty ? pair.en : "\(pair.en) — \(pair.ru)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var definitions: some View {
        VStack(alignment: .leading, spacing: PopupMetrics.rowGap) {
            ForEach(Array(state.definitionsItems.enumerated()), id: \.offset) { index, item in
                NumberedRow(number: index + 1) {
                    Text(item)
                        .font(.body)
                        .foregroundStyle(.primary)
                }
            }
        }
    }

    private var examples: some View {
        VStack(alignment: .leading, spacing: PopupMetrics.rowGap) {
            ForEach(Array(state.examples.enumerated()), id: \.offset) { _, example in
                Text(example.en)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
            }
        }
    }

    // MARK: - Banner and footer

    @ViewBuilder
    private var bottom: some View {
        if let banner = model.banner {
            BannerRow(banner: banner)
                // Alone (an announcement) it gets the panel's own vertical rhythm.
                .padding(.top, query.isEmpty ? 12 : 2)
                .padding(.bottom, hasResult ? 6 : 12)
        }
        if hasResult {
            footer
                // A new showing starts with no row under the pointer: a row hovered when
                // the panel was last hidden never heard the pointer leave.
                .id(chrome.showCount)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .padding(.horizontal, PopupMetrics.separatorInset)
                .padding(.bottom, PopupMetrics.separatorInset)
            MenuRow(
                title: "Add to Anki…",
                chrome: chrome,
                shortcut: KeyHint(key: "↩"),
                keyboardShortcut: .defaultAction,
                disabledReason: ankiUnavailableReason,
                action: onOpenAnki
            )
            MenuRow(
                title: "Copy Translation",
                chrome: chrome,
                shortcut: KeyHint(modifiers: "⇧⌘", key: "C"),
                keyboardShortcut: KeyboardShortcut("c", modifiers: [.shift, .command]),
                disabledReason: state.hasTranslation ? nil : "There is no translation to copy.",
                action: copyTranslation
            )
            if state.canRefreshExamples {
                MenuRow(
                    title: "New Examples",
                    chrome: chrome,
                    shortcut: KeyHint(modifiers: "⌘", key: "R"),
                    keyboardShortcut: KeyboardShortcut("r", modifiers: .command),
                    busy: state.refreshingExamples,
                    disabledReason: state.refreshingExamples ? "Looking for other examples." : nil
                ) {
                    Task { await model.refreshExamples() }
                }
            }
        }
        .padding(.horizontal, PopupMetrics.rowInset)
        .padding(.bottom, PopupMetrics.rowInset)
    }

    private var ankiUnavailableReason: String? {
        if !model.ankiStatus.available { return "Anki isn't running, or AnkiConnect isn't installed." }
        if !state.canAddAnki { return "This result can't be added to Anki." }
        return nil
    }

    private func copyTranslation() {
        guard state.hasTranslation else { return }
        SelectionCapture.writeToPasteboard(state.translationText)
        model.show(banner: "Translation copied.", level: .success)
    }
}

// MARK: - Metrics

/// Maccy's popup geometry on macOS 26: rows inset 5 pt from the panel edge, their text a
/// further 10 pt in, highlights with 7 pt corners so they stay concentric with the 12 pt
/// panel.
enum PopupMetrics {
    static let rowInset: CGFloat = 5
    static let textInset: CGFloat = 15
    static let rowHeight: CGFloat = 24
    static let rowRadius: CGFloat = 7
    static let separatorInset: CGFloat = 6
    static let rowGap: CGFloat = 8
    static let numberColumn: CGFloat = 18
    static let numberSpacing: CGFloat = 6
    static let indicatorInset: CGFloat = 6
}

/// Set by the panel controller: whether the panel is capped, so the body scrolls.
@MainActor
@Observable
final class PopupChrome {
    var bodyScrolls = false
    /// Snapshot runs only: the row drawn as if the pointer were on it, since a capture
    /// has no pointer.
    var highlightedRowForSnapshot: String?
    /// Bumped on every show.
    var showCount = 0
}

/// Natural heights of the parts, kept outside SwiftUI's state so writing one does not
/// trigger another layout pass.
private final class HeightParts {
    var header: CGFloat = 0
    var body: CGFloat = 0
    var bottom: CGFloat = 0
    var total: CGFloat { header + body + bottom }
}

// MARK: - Pieces

private struct SectionHeader: View {
    let title: String
    var first: Bool

    init(_ title: String, first: Bool) {
        self.title = title
        self.first = first
    }

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.top, first ? 0 : 14)
            .padding(.bottom, 4)
            .accessibilityAddTraits(.isHeader)
    }
}

/// A numbers column (fixed width, trailing-aligned) and a content column.
private struct NumberedRow<Content: View>: View {
    let number: Int
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: PopupMetrics.numberSpacing) {
            Text("\(number)")
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: PopupMetrics.numberColumn, alignment: .trailing)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct BannerRow: View {
    let banner: AppModel.BannerMessage

    var body: some View {
        Label {
            Text(banner.text)
                .font(.callout)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: banner.level.panelSymbol)
                .foregroundStyle(banner.level.panelTint)
        }
        .font(.callout)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, PopupMetrics.textInset)
        .accessibilityElement(children: .combine)
    }
}

/// A shortcut hint drawn like Maccy's: one glyph per modifier, the key in a fixed cell.
struct KeyHint: View {
    var modifiers: String = ""
    var key: String

    var body: some View {
        HStack(spacing: 1) {
            ForEach(Array(modifiers.enumerated()), id: \.offset) { _, glyph in
                Text(String(glyph))
            }
            Text(key).frame(width: 12, alignment: .center)
        }
        .lineLimit(1)
        .opacity(0.7)
        .accessibilityHidden(true)
    }
}

/// A footer row that looks and highlights exactly like a menu item.
private struct MenuRow: View {
    let title: String
    let chrome: PopupChrome
    let shortcut: KeyHint
    let keyboardShortcut: KeyboardShortcut
    var busy = false
    /// Non-nil disables the row and says why.
    var disabledReason: String?
    let action: () -> Void

    @State private var hovering = false

    private var enabled: Bool { disabledReason == nil }
    private var highlighted: Bool {
        (hovering || chrome.highlightedRowForSnapshot == title) && enabled
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                Text(title)
                    .font(.body)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if busy {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.8)
                        .frame(height: 16)
                } else {
                    shortcut.font(.body)
                }
            }
            .padding(.horizontal, PopupMetrics.textInset - PopupMetrics.rowInset)
            .frame(maxWidth: .infinity, minHeight: PopupMetrics.rowHeight, alignment: .leading)
            .foregroundStyle(highlighted ? AnyShapeStyle(Color.white) : enabled ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
            // macOS 26 needs some background for hover to register (Maccy's workaround).
            .background(
                highlighted ? AnyShapeStyle(Color.accentColor.opacity(0.8)) : AnyShapeStyle(Color.white.opacity(0.001)),
                in: .rect(cornerRadius: PopupMetrics.rowRadius, style: .continuous)
            )
            .contentShape(.rect(cornerRadius: PopupMetrics.rowRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .keyboardShortcut(keyboardShortcut)
        .disabled(!enabled)
        .onHover { hovering = $0 }
        .help(disabledReason ?? "")
        .accessibilityLabel(title)
        .accessibilityHint(disabledReason ?? "")
    }
}

/// Lets the bare background of the panel drag the window, as a title bar would.
private struct WindowDragArea: View {
    var body: some View {
        Color.clear
            .contentShape(.rect)
            .gesture(WindowDragGesture())
    }
}

extension NotificationLevel {
    /// The status symbol shown in the panel's banner row.
    var panelSymbol: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }

    var panelTint: Color {
        switch self {
        case .success: return .green
        case .info: return .secondary
        case .warning: return .orange
        case .error: return .red
        }
    }
}
