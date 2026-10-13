import CmuxSidebar
import Foundation
import Observation

/// Owns tab search state above the sidebar's lazy row boundary.
@MainActor
@Observable
final class SidebarTabBrowserModel {
    struct Request: Equatable {
        let query: String
        let entries: [SidebarTabSearch.Entry]
    }

    var query = "" {
        didSet { if query != oldValue { updateNameMatches() } }
    }
    private(set) var entries: [SidebarTabSearch.Entry] = []
    private(set) var matches: [SidebarTabSearch.Entry] = []
    private(set) var isSearchingContent = false
    private(set) var matchedByContent = false
    private let search = SidebarTabSearch()
    @ObservationIgnored private let defaults: UserDefaults
    private let order = SidebarSurfaceOrder()
    static let orderDefaultsKey = "sidebar.tabs.surfaceOrder.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var request: Request { Request(query: query, entries: entries) }
    var isFiltering: Bool { !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var matchingWorkspaceIDs: Set<UUID> { Set(matches.map(\.workspaceID)) }

    func replaceEntries(_ entries: [SidebarTabSearch.Entry]) {
        let stored = defaults.dictionary(forKey: Self.orderDefaultsKey) as? [String: [String]] ?? [:]
        let preferredOrder = stored.reduce(into: [UUID: [UUID]]()) { result, pair in
            guard let workspaceID = UUID(uuidString: pair.key) else { return }
            result[workspaceID] = pair.value.compactMap(UUID.init(uuidString:))
        }
        let ordered = order.orderedEntries(entries, preferredOrder: preferredOrder)
        guard self.entries != ordered else { return }
        self.entries = ordered
        updateNameMatches()
    }

    func canReorder(_ draggedID: UUID, relativeTo targetID: UUID) -> Bool {
        draggedID != targetID && order.reordering(
            entries, draggedID: draggedID, targetID: targetID, placement: .before
        ) != nil
    }

    /// Saves one workspace's complete order; filtering never drops hidden tabs.
    @discardableResult
    func reorder(_ draggedID: UUID, relativeTo targetID: UUID, placement: SidebarSurfaceOrder.Placement) -> Bool {
        guard let reordered = order.reordering(
            entries, draggedID: draggedID, targetID: targetID, placement: placement
        ), let workspaceID = reordered.first(where: { $0.id == draggedID })?.workspaceID else { return false }
        guard reordered != entries else { return true }
        var stored = defaults.dictionary(forKey: Self.orderDefaultsKey) as? [String: [String]] ?? [:]
        stored[workspaceID.uuidString] = reordered.filter { $0.workspaceID == workspaceID }.map { $0.id.uuidString }
        defaults.set(stored, forKey: Self.orderDefaultsKey)
        entries = reordered
        updateNameMatches()
        return true
    }

    /// Yields between surface captures so a newer query cancels stale work.
    func searchContent(content: @MainActor (SidebarTabSearch.Entry) -> String?) async {
        guard isFiltering, search.nameMatches(query: query, entries: entries).isEmpty else { return }
        let requestedQuery = query
        let requestedEntries = entries
        var results: [SidebarTabSearch.Entry] = []
        for entry in requestedEntries {
            await Task.yield()
            guard !Task.isCancelled, query == requestedQuery, entries == requestedEntries else { return }
            if let text = content(entry), search.contains(query: requestedQuery, text: text) {
                results.append(entry)
            }
        }
        guard !Task.isCancelled, query == requestedQuery, entries == requestedEntries else { return }
        matches = results
        matchedByContent = !results.isEmpty
        isSearchingContent = false
    }

    private func updateNameMatches() {
        matches = search.nameMatches(query: query, entries: entries)
        matchedByContent = false
        isSearchingContent = isFiltering && matches.isEmpty
    }
}
