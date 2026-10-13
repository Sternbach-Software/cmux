import Foundation
import Testing
@testable import CmuxSidebar

struct SidebarSurfaceOrderTests {
    private let order = SidebarSurfaceOrder()
    private let workspaceID = UUID()

    private func entry(_ title: String, pinned: Bool = false) -> SidebarTabSearch.Entry {
        .init(id: UUID(), workspaceID: workspaceID, title: title, isPinned: pinned)
    }

    @Test func pinnedTabsComeFirstWhileWorkspaceOrderIsPreserved() {
        let a = entry("Shell")
        let b = entry("Pinned", pinned: true)
        let other = SidebarTabSearch.Entry(id: UUID(), workspaceID: UUID(), title: "Other")
        #expect(order.orderedEntries([a, b, other], preferredOrder: [:]) == [b, a, other])
    }

    @Test func savedOrderRestoresBothPinSections() {
        let tabs = [entry("P1", pinned: true), entry("P2", pinned: true), entry("U1"), entry("U2")]
        let saved = [tabs[3].id, tabs[1].id, tabs[2].id, tabs[0].id]
        #expect(order.orderedEntries(tabs, preferredOrder: [workspaceID: saved]) == [tabs[1], tabs[0], tabs[3], tabs[2]])
    }

    @Test(arguments: [false, true]) func tabsMoveUpAndDownWithinTheirPinSection(pinned: Bool) {
        let tabs = [entry("A", pinned: pinned), entry("B", pinned: pinned), entry("C", pinned: pinned)]
        #expect(order.reordering(tabs, draggedID: tabs[0].id, targetID: tabs[2].id, placement: .after) == [tabs[1], tabs[2], tabs[0]])
        #expect(order.reordering(tabs, draggedID: tabs[2].id, targetID: tabs[0].id, placement: .before) == [tabs[2], tabs[0], tabs[1]])
        #expect(order.reordering(tabs, draggedID: tabs[0].id, targetID: tabs[2].id, placement: .before) == [tabs[1], tabs[0], tabs[2]])
    }

    @Test func dropsCannotCrossPinSectionsOrWorkspaces() {
        let pinned = entry("Pinned", pinned: true)
        let unpinned = entry("Shell")
        let other = SidebarTabSearch.Entry(id: UUID(), workspaceID: UUID(), title: "Other")
        let tabs = [pinned, unpinned, other]
        #expect(order.reordering(tabs, draggedID: pinned.id, targetID: unpinned.id, placement: .after) == nil)
        #expect(order.reordering(tabs, draggedID: unpinned.id, targetID: pinned.id, placement: .before) == nil)
        #expect(order.reordering(tabs, draggedID: unpinned.id, targetID: other.id, placement: .after) == nil)
    }

    @Test func movingSearchMatchesKeepsHiddenTabsAndOtherWorkspaces() throws {
        let a = entry("Match A")
        let hidden = entry("Hidden")
        let b = entry("Match B")
        let other = SidebarTabSearch.Entry(id: UUID(), workspaceID: UUID(), title: "Other")
        let moved = try #require(order.reordering([a, hidden, b, other], draggedID: b.id, targetID: a.id, placement: .before))
        #expect(moved == [b, a, hidden, other])
        #expect(SidebarTabSearch().nameMatches(query: "Match", entries: moved) == [b, a])
    }

    @Test func savedIdentitiesSurviveRenamesAndIgnoreClosedDuplicateOrForeignTabs() {
        let original = entry("Original")
        let renamed = SidebarTabSearch.Entry(id: original.id, workspaceID: workspaceID, title: "Renamed")
        let existing = entry("Existing")
        let newPinned = entry("New pinned", pinned: true)
        let newUnpinned = entry("New unpinned")
        let saved = [UUID(), original.id, original.id, existing.id]
        #expect(order.orderedEntries([existing, renamed, newUnpinned, newPinned], preferredOrder: [workspaceID: saved]) == [newPinned, renamed, existing, newUnpinned])
    }

    @Test func changedPinStateCannotEscapeThePinnedSection() {
        let a = entry("A")
        let b = entry("B", pinned: true)
        let newlyPinned = SidebarTabSearch.Entry(id: a.id, workspaceID: workspaceID, title: a.title, isPinned: true)
        let c = entry("C")
        #expect(order.orderedEntries([newlyPinned, b, c], preferredOrder: [workspaceID: [c.id, b.id, a.id]]) == [b, newlyPinned, c])
    }

    @Test func staleDropsFailAndDroppingOnItselfIsANoOp() {
        let tab = entry("Shell")
        #expect(order.reordering([tab], draggedID: UUID(), targetID: tab.id, placement: .before) == nil)
        #expect(order.reordering([tab], draggedID: tab.id, targetID: UUID(), placement: .after) == nil)
        #expect(order.reordering([tab], draggedID: tab.id, targetID: tab.id, placement: .after) == [tab])
    }
}
