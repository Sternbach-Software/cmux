public import Foundation

/// Persistent sidebar ordering of tabs, independent of the workspace's split layout.
public struct SidebarSurfaceOrder: Sendable {
    /// Which side of the hovered tab receives the dragged tab.
    public enum Placement: Equatable, Sendable {
        /// Insert immediately before the target.
        case before
        /// Insert immediately after the target.
        case after
    }

    /// Creates the sidebar tab ordering policy.
    public init() {}

    /// Applies saved tab identities within each workspace, keeping pinned tabs first.
    /// Missing saved tabs are ignored; newly created tabs append to their pin section.
    ///
    /// - Parameters:
    ///   - entries: Current tabs in workspace and pane order.
    ///   - preferredOrder: Saved tab identities keyed by workspace identity.
    /// - Returns: All current tabs, grouped by workspace and pin state.
    public func orderedEntries(
        _ entries: [SidebarTabSearch.Entry],
        preferredOrder: [UUID: [UUID]]
    ) -> [SidebarTabSearch.Entry] {
        let byWorkspace = Dictionary(grouping: entries, by: \.workspaceID)
        var seenWorkspaces: Set<UUID> = []
        return entries.flatMap { entry -> [SidebarTabSearch.Entry] in
            guard seenWorkspaces.insert(entry.workspaceID).inserted,
                  let workspaceEntries = byWorkspace[entry.workspaceID] else { return [] }
            let byID = Dictionary(uniqueKeysWithValues: workspaceEntries.map { ($0.id, $0) })
            var seen: Set<UUID> = []
            let saved = (preferredOrder[entry.workspaceID] ?? []).compactMap { id -> SidebarTabSearch.Entry? in
                guard let tab = byID[id], seen.insert(id).inserted else { return nil }
                return tab
            }
            let ordered = saved + workspaceEntries.filter { !seen.contains($0.id) }
            return ordered.filter(\.isPinned) + ordered.filter { !$0.isPinned }
        }
    }

    /// Reorders a tab within its current workspace and pin section.
    /// Use the complete tab list, including tabs hidden by a search filter.
    ///
    /// - Parameters:
    ///   - entries: The complete sidebar order.
    ///   - draggedID: The tab being dragged.
    ///   - targetID: The hovered tab.
    ///   - placement: Whether to insert before or after the target.
    /// - Returns: The new order, or nil for a stale tab or a different workspace/pin section.
    public func reordering(
        _ entries: [SidebarTabSearch.Entry],
        draggedID: UUID,
        targetID: UUID,
        placement: Placement
    ) -> [SidebarTabSearch.Entry]? {
        guard let sourceIndex = entries.firstIndex(where: { $0.id == draggedID }),
              let target = entries.first(where: { $0.id == targetID }),
              entries[sourceIndex].workspaceID == target.workspaceID,
              entries[sourceIndex].isPinned == target.isPinned else { return nil }
        guard draggedID != targetID else { return entries }
        var result = entries
        let dragged = result.remove(at: sourceIndex)
        guard let targetIndex = result.firstIndex(where: { $0.id == targetID }) else { return nil }
        result.insert(dragged, at: targetIndex + (placement == .after ? 1 : 0))
        return result
    }
}
