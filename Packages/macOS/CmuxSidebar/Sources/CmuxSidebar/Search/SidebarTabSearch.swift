public import Foundation

/// Searches tab names before consulting locally available tab content.
public struct SidebarTabSearch: Sendable {
    /// An immutable tab identity and its current display name.
    public struct Entry: Equatable, Identifiable, Sendable {
        /// The panel identity, preserved across renames.
        public let id: UUID
        /// The workspace containing this panel.
        public let workspaceID: UUID
        /// The resolved name also displayed in the pane's tab bar.
        public let title: String
        /// The tab's SF Symbol, when available.
        public let icon: String?

        /// Creates a sidebar tab value.
        ///
        /// - Parameters:
        ///   - id: The panel identity.
        ///   - workspaceID: The containing workspace identity.
        ///   - title: The resolved tab name.
        ///   - icon: An optional SF Symbol name.
        public init(id: UUID, workspaceID: UUID, title: String, icon: String? = nil) {
            self.id = id
            self.workspaceID = workspaceID
            self.title = title
            self.icon = icon
        }
    }

    /// Creates a case- and accent-insensitive substring search.
    public init() {}

    /// Finds names in sidebar order; an empty query returns all tabs.
    ///
    /// - Parameters:
    ///   - query: The text entered in the sidebar.
    ///   - entries: The current tabs in display order.
    /// - Returns: Matching tab values in their original order.
    public func nameMatches(query: String, entries: [Entry]) -> [Entry] {
        let query = normalizedQuery(query)
        guard !query.isEmpty else { return entries }
        return entries.filter { contains(query: query, text: $0.title) }
    }

    /// Finds names first and reads content only if no name matches anywhere.
    ///
    /// - Parameters:
    ///   - query: The text entered in the sidebar.
    ///   - entries: The current tabs in display order.
    ///   - content: Supplies available local text for a tab, or nil.
    /// - Returns: Name matches, or content matches when there are no name matches.
    public func matches(query: String, entries: [Entry], content: (Entry) -> String?) -> [Entry] {
        let names = nameMatches(query: query, entries: entries)
        guard names.isEmpty, !normalizedQuery(query).isEmpty else { return names }
        return entries.filter { entry in
            content(entry).map { contains(query: query, text: $0) } ?? false
        }
    }

    /// Reports whether text contains a nonempty query, ignoring case and accents.
    ///
    /// - Parameters:
    ///   - query: The search text; surrounding whitespace is ignored.
    ///   - text: A tab name or its available content.
    /// - Returns: Whether the normalized query appears in the text.
    public func contains(query: String, text: String) -> Bool {
        let query = normalizedQuery(query)
        guard !query.isEmpty else { return false }
        return text.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    private func normalizedQuery(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
