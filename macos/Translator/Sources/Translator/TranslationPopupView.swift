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
    /// A footer row was clicked or its shortcut pressed; the panel controller runs it.
    var onActivate: (PopupFooterRow) -> Void

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

    /// The panel holds an announcement. The lookup stays in the model underneath it —
    /// Add to Anki may be reading it — and is simply not drawn.
    private var announcing: Bool { chrome.announcing }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        if !announcing, !query.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if isSentence {
                        Text(query)
                            .font(.body)
                            .popupSecondaryText()
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
                        .popupSecondaryText()
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
        if announcing {
            EmptyView()
        } else if hasResult {
            VStack(alignment: .leading, spacing: 0) {
                if state.hasTranslation {
                    let paragraphs = PopupContent.translationParagraphs(state.translationText)
                    if let main = paragraphs.first {
                        Text(main)
                            .font(.title3)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    // A sentence's alternatives, labelled: unlabelled they read as the
                    // source text again, or as the rest of the translation.
                    if paragraphs.count > 1 {
                        SectionHeader("Other Translations", first: false)
                        VStack(alignment: .leading, spacing: PopupMetrics.rowGap) {
                            ForEach(Array(paragraphs.dropFirst().enumerated()), id: \.offset) { _, paragraph in
                                Text(paragraph)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
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
            if let error = model.lastError {
                // A fault, not an empty result: it carries its status symbol, as the
                // banner that would otherwise repeat it does.
                BannerRow(text: error, level: model.lastErrorLevel)
                    .textSelection(.enabled)
                    .padding(.top, 2)
                    .padding(.bottom, 12)
            } else {
                Text("No translation for “\(query)”.")
                    .font(.body)
                    .popupSecondaryText()
                    .textSelection(.enabled)
                    .padding(.horizontal, PopupMetrics.textInset)
                    .padding(.bottom, 12)
            }
        }
    }

    private func dictionary(_ apple: AppleLexical) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(apple.groupedEntries.enumerated()), id: \.offset) { groupIndex, entry in
                if !entry.pos.isEmpty {
                    Text(entry.pos)
                        .font(.callout.italic())
                        .popupSecondaryText()
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
                        .popupSecondaryText()
                }
                ForEach(Array(sense.examples.enumerated()), id: \.offset) { _, pair in
                    Text(pair.ru.isEmpty ? pair.en : "\(pair.en) — \(pair.ru)")
                        .font(.callout)
                        .popupSecondaryText()
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

    /// A failed lookup says why in the body; the banner with the same words would say it
    /// a second time.
    private var visibleBanner: AppModel.BannerMessage? {
        guard let banner = model.banner else { return nil }
        if isNoResult, banner.text == model.lastError { return nil }
        return banner
    }

    @ViewBuilder
    private var bottom: some View {
        if announcing {
            // Alone, it gets the panel's own vertical rhythm. Nothing at all once it is
            // gone, and the panel then hides rather than stay up as empty glass.
            if let announcement = chrome.announcement {
                BannerRow(text: announcement.text, level: announcement.level)
                    .padding(.vertical, 12)
            }
        } else if let banner = visibleBanner {
            BannerRow(text: banner.text, level: banner.level)
                .padding(.top, query.isEmpty ? 12 : 2)
                .padding(.bottom, hasResult ? 6 : 12)
        }
        if !announcing, hasResult {
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
            ForEach(PopupFooter.rows(for: model), id: \.row) { item in
                MenuRow(item: item, chrome: chrome) { onActivate(item.row) }
            }
        }
        .padding(.horizontal, PopupMetrics.rowInset)
        .padding(.bottom, PopupMetrics.rowInset)
    }
}

// MARK: - Footer rows

/// One footer row as it stands now.
struct FooterRowState {
    let row: PopupFooterRow
    /// What the row says; the examples row's depends on whether there are any.
    var title: String
    /// Non-nil disables the row and says why.
    let disabledReason: String?
    var busy = false

    var enabled: Bool { disabledReason == nil }
}

/// Which footer rows show and which work: read by the view to draw them and by the
/// panel controller to move the keyboard highlight through them.
@MainActor
enum PopupFooter {
    /// Empty until there is a result: the footer shows only then.
    static func rows(for model: AppModel) -> [FooterRowState] {
        let state = model.state
        guard PopupContent.hasResult(state) else { return [] }
        var rows = [
            FooterRowState(
                row: .addToAnki, title: PopupFooterRow.addToAnki.title,
                disabledReason: ankiUnavailableReason(model)
            ),
            FooterRowState(
                row: .copyTranslation, title: PopupFooterRow.copyTranslation.title,
                disabledReason: state.hasTranslation ? nil : "There’s no translation to copy."
            ),
        ]
        if let title = PopupFooterRow.examplesTitle(
            canRefresh: state.canRefreshExamples,
            isSentence: PopupLayout.isSentence(state.originalText),
            hasExamples: !state.examples.isEmpty
        ) {
            rows.append(FooterRowState(
                row: .newExamples, title: title,
                disabledReason: state.refreshingExamples ? "Looking for examples." : nil,
                busy: state.refreshingExamples
            ))
        }
        return rows
    }

    private static func ankiUnavailableReason(_ model: AppModel) -> String? {
        if !model.ankiStatus.available { return "Anki isn’t running, or AnkiConnect isn’t installed." }
        if !model.state.canAddAnki { return "This result can’t be added to Anki." }
        return nil
    }
}

extension PopupFooterRow {
    var hint: KeyHint {
        switch self {
        case .addToAnki: return KeyHint(key: "↩")
        case .copyTranslation: return KeyHint(modifiers: "⇧⌘", key: "C")
        case .newExamples: return KeyHint(modifiers: "⌘", key: "R")
        }
    }

    /// ⌘C stays free for copying a text selection, so copying the translation is ⇧⌘C.
    var keyboardShortcut: KeyboardShortcut {
        switch self {
        case .addToAnki: return .defaultAction
        case .copyTranslation: return KeyboardShortcut("c", modifiers: [.shift, .command])
        case .newExamples: return KeyboardShortcut("r", modifiers: .command)
        }
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

/// Set by the panel controller: whether the panel is capped, so the body scrolls, and
/// which footer row is highlighted.
@MainActor
@Observable
final class PopupChrome {
    var bodyScrolls = false
    /// The one highlighted footer row, as in a menu: the pointer puts it there, and so do
    /// ↑/↓. Cleared on every show.
    var highlightedRow: PopupFooterRow?
    /// Bumped on every show.
    var showCount = 0
    /// This showing is an announcement: only its message is drawn, never the lookup the
    /// model still holds.
    var announcing = false
    /// The announcement's message; nil once it is over.
    var announcement: AppModel.BannerMessage?
}

/// Natural heights of the parts, kept outside SwiftUI's state so writing one does not
/// trigger another layout pass.
private final class HeightParts {
    var header: CGFloat = 0
    var body: CGFloat = 0
    var bottom: CGFloat = 0
    var total: CGFloat { header + body + bottom }
}

// Selectable SwiftUI text inside NSGlassEffectView can flatten hierarchical shape
// styles. Keep AppKit's adaptive primary foreground and apply the secondary tone to
// the view, after the glass treatment, so pronunciations/examples stay subordinate.
private extension View {
    func popupSecondaryText() -> some View {
        foregroundStyle(.primary).opacity(0.65)
    }
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
            .popupSecondaryText()
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
                .popupSecondaryText()
                .frame(width: PopupMetrics.numberColumn, alignment: .trailing)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

/// A status line: a banner, an announcement, or the reason a lookup failed.
private struct BannerRow: View {
    let text: String
    let level: NotificationLevel

    var body: some View {
        Label {
            Text(text)
                .font(.callout)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: level.panelSymbol)
                .foregroundStyle(level.panelTint)
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

    /// The glyphs are hidden from VoiceOver; the row says this instead ("Shift-Command-C").
    var spoken: String { KeyGlyphs.spoken(modifiers: modifiers, key: key) }

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
    let item: FooterRowState
    let chrome: PopupChrome
    let action: () -> Void

    private var title: String { item.title }
    private var enabled: Bool { item.enabled }
    private var highlighted: Bool { chrome.highlightedRow == item.row && enabled }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                Text(title)
                    .font(.body)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if item.busy {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.8)
                        .frame(height: 16)
                } else {
                    item.row.hint.font(.body)
                }
            }
            .padding(.horizontal, PopupMetrics.textInset - PopupMetrics.rowInset)
            .frame(maxWidth: .infinity, minHeight: PopupMetrics.rowHeight, alignment: .leading)
            .foregroundStyle(highlighted ? Color.white : Color.primary)
            .opacity(enabled ? 1 : 0.4)
            // macOS 26 needs some background for hover to register (Maccy's workaround).
            .background(
                highlighted ? AnyShapeStyle(Color.accentColor.opacity(0.8)) : AnyShapeStyle(Color.white.opacity(0.001)),
                in: .rect(cornerRadius: PopupMetrics.rowRadius, style: .continuous)
            )
            .contentShape(.rect(cornerRadius: PopupMetrics.rowRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .keyboardShortcut(item.row.keyboardShortcut)
        .disabled(!enabled)
        // The pointer and the arrow keys share one highlight, as in a menu.
        .onHover { inside in
            if inside {
                chrome.highlightedRow = item.row
            } else if chrome.highlightedRow == item.row {
                chrome.highlightedRow = nil
            }
        }
        .help(item.disabledReason ?? "")
        .accessibilityLabel(title)
        // The shortcut glyphs are hidden from VoiceOver, so the hint says the shortcut.
        .accessibilityHint(item.disabledReason ?? item.row.hint.spoken)
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
