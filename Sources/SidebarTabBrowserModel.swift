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

    var request: Request { Request(query: query, entries: entries) }
    var isFiltering: Bool { !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var matchingWorkspaceIDs: Set<UUID> { Set(matches.map(\.workspaceID)) }

    func replaceEntries(_ entries: [SidebarTabSearch.Entry]) {
        guard self.entries != entries else { return }
        self.entries = entries
        updateNameMatches()
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
