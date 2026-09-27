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

    /// Wide enough that the toolbar's search field has its full width beside the title,
    /// so focusing it does not push the title into an overflow menu.
    static let defaultSize = CGSize(width: 520, height: 540)

    @State private var query = ""
    @State private var selection: Int?
    /// The first answer has arrived. Until then an empty list means "not asked yet", and
    /// saying "No History" would be a claim the app cannot make.
    @State private var didLoad = false

    private var filtered: [HistoryItem] {
        let needle = query.trimmingCharacters(in: .whitespaces)
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
                    .disabled(item.translation.isEmpty)
            }
        } primaryAction: { ids in
            // Double-click and Return.
            if let id = ids.first { onOpen(id) }
        }
        .overlay { emptyState }
        .searchable(text: $query, placement: .toolbar)
        .frame(minWidth: 420, minHeight: 360)
        .task {
            await model.loadHistory()
            didLoad = true
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if model.history.isEmpty {
            if didLoad {
                ContentUnavailableView(
                    "No History",
                    systemImage: "clock",
                    description: Text("Words you translate appear here.")
                )
            }
        } else if filtered.isEmpty {
            ContentUnavailableView.search(text: query.trimmingCharacters(in: .whitespaces))
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
            if !item.translation.isEmpty {
                Text(item.translation)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }
}
