import AppKit
import SwiftUI
import TranslatorCore

/// Past lookups. Opening a row shows it in the popup again without hitting the network.
///
/// A plain `List` with selection, so arrow keys, Return, double-click and the context menu
/// all behave the way they do in every other Mac list. The search field is `.searchable`,
/// which the hosting controller bridges into the window's toolbar.
struct HistoryView: View {
    @Bindable var model: AppModel
    var onOpen: (Int) -> Void
    /// Puts the list at its very top, top margin included. Neither `scrollTo(id, anchor:
    /// .top)`, which leaves the first row flush under the toolbar, nor `ScrollPosition`,
    /// which a `List` ignores, does that; the window's scroll view does.
    var scrollToTop: () -> Void

    /// Wide enough that the toolbar's search field has its full width beside the title,
    /// so focusing it does not push the title into an overflow menu.
    static let defaultSize = CGSize(width: 520, height: 540)

    @State private var query = ""
    @State private var selection: Int?
    /// The first answer has arrived. Until then an empty list means "not asked yet", and
    /// saying "No History" would be a claim the app cannot make.
    @State private var didLoad = false

    private var filtered: [HistoryItem] {
        let needle = needle
        guard !needle.isEmpty else { return model.history }
        return model.history.filter {
            $0.text.localizedStandardContains(needle) || $0.translation.localizedStandardContains(needle)
        }
    }

    var body: some View {
        List(filtered, selection: $selection) { item in
            HistoryRow(item: item)
        }
        .contextMenu(forSelectionType: Int.self) { ids in
            if let id = ids.first, let item = model.history.first(where: { $0.entryId == id }) {
                Button("Open") { onOpen(id) }
                Divider()
                Button("Copy Word") { Self.copy(item.text) }
                Button("Copy Translation") { Self.copy(item.translation) }
                    .disabled(!item.hasTranslation)
            }
        } primaryAction: { ids in
            // Double-click and Return.
            if let id = ids.first { onOpen(id) }
        }
        // Edit > Copy and ⌘C copy the selected word, as in any Mac list.
        .onCopyCommand {
            guard let id = selection, let item = model.history.first(where: { $0.entryId == id }) else { return [] }
            return [NSItemProvider(object: item.text as NSString)]
        }
        // A reload that failed over rows already shown: they stay, and the window says
        // they may be out of date rather than passing them off as current.
        .safeAreaInset(edge: .top, spacing: 0) {
            if let error = model.historyLoadError, !model.history.isEmpty {
                staleNotice(error)
            }
        }
        // The list keeps its place between opens, and each row a lookup added at the top
        // meanwhile pushes that place further down: reopened, it would start part way down
        // with the newest word half under the toolbar. A reopened History starts at its
        // top edge, unless the user left a selection or a search to come back to.
        .onChange(of: model.historyReopens) {
            guard selection == nil, needle.isEmpty else { return }
            scrollToTop()
        }
        // The same for a lookup made while the window is open, when the list was at its
        // top: the new row is the one the user just looked up.
        .onChange(of: model.historyTopReloads) {
            guard selection == nil, needle.isEmpty else { return }
            scrollToTop()
        }
        .overlay { emptyState }
        .searchable(text: $query, placement: .toolbar)
        .frame(minWidth: 420, minHeight: 360)
        .task {
            await model.loadHistory()
            didLoad = true
        }
        .alert(
            model.historyOpenFailure.map { $0.word.isEmpty ? "Can’t Open the Entry" : "Can’t Open “\($0.word)”" } ?? "",
            isPresented: Binding(
                get: { model.historyOpenFailure != nil },
                set: { if !$0 { model.historyOpenFailure = nil } }
            ),
            presenting: model.historyOpenFailure
        ) { _ in
            Button("OK") {}
        } message: { failure in
            Text(failure.message)
        }
    }

    private var needle: String { query.trimmingCharacters(in: .whitespaces) }

    private func staleNotice(_ error: String) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label {
                    Text("Can’t update History. \(error)")
                        .lineLimit(2)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                }
                Spacer(minLength: 8)
                Button("Try Again") { Task { await model.loadHistory() } }
                    .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            Divider()
        }
        .background(.bar)
    }

    @ViewBuilder
    private var emptyState: some View {
        if model.history.isEmpty {
            if let error = model.historyLoadError {
                // Not "No History": the list is empty because nobody could ask for it.
                ContentUnavailableView {
                    Label("Can’t Load History", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Try Again") { Task { await model.loadHistory() } }
                }
            } else if didLoad {
                ContentUnavailableView(
                    "No History",
                    systemImage: "clock",
                    description: Text("Words you translate appear here.")
                )
            }
        } else if filtered.isEmpty {
            ContentUnavailableView.search(text: needle)
        }
    }

    private static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

private struct HistoryRow: View {
    let item: HistoryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(item.text)
                .lineLimit(1)
            Text(item.hasTranslation ? item.translation : "No translation")
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }
}

private extension HistoryItem {
    /// A lookup that found nothing is stored with the query as its translation; showing
    /// "qwzxv" under "qwzxv" would read as a fault rather than as "nothing found".
    var hasTranslation: Bool {
        let translation = translation.trimmingCharacters(in: .whitespacesAndNewlines)
        return !translation.isEmpty
            && translation.compare(text.trimmingCharacters(in: .whitespacesAndNewlines), options: .caseInsensitive) != .orderedSame
    }
}
