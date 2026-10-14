import Foundation
import Testing
@testable import CmuxSidebar

struct SidebarTabSearchTests {
    private let search = SidebarTabSearch()
    private let workspaceID = UUID()

    private func entry(_ title: String) -> SidebarTabSearch.Entry {
        .init(id: UUID(), workspaceID: workspaceID, title: title)
    }

    @Test func emptyQueryReturnsAllTabsWithoutReadingContent() {
        let tabs = [entry("Shell"), entry("Build")]
        let matches = search.matches(query: "  \n", entries: tabs) { _ in
            Issue.record("An empty search must not read content")
            return nil
        }
        #expect(matches == tabs)
    }

    @Test func nameMatchesTakePriorityAcrossWorkspaces() {
        let named = entry("Deploy logs")
        let other = SidebarTabSearch.Entry(id: UUID(), workspaceID: UUID(), title: "Shell")
        let matches = search.matches(query: "DEPLOY", entries: [other, named]) { _ in
            Issue.record("Name matches must prevent every content capture")
            return "deploy"
        }
        #expect(matches == [named])
    }

    @Test func noNamesFallsBackToAvailableContentInSidebarOrder() {
        let tabs = [entry("Shell"), entry("Build"), entry("Unavailable")]
        let text = [tabs[0].id: "compiler: café warning", tabs[1].id: "CAFE is ready"]
        #expect(search.matches(query: " cafe ", entries: tabs) { text[$0.id] } == Array(tabs.prefix(2)))
    }

    @Test func namesIgnoreCaseAccentsAndSurroundingWhitespace() {
        let tabs = [entry("Café server"), entry("Build")]
        #expect(search.nameMatches(query: " CAFE ", entries: tabs) == [tabs[0]])
    }

    @Test func unrelatedAndUnavailableContentProducesNoResults() {
        let tabs = [entry("Shell"), entry("Browser")]
        #expect(search.matches(query: "missing", entries: tabs) { _ in nil }.isEmpty)
        #expect(search.matches(query: "missing", entries: tabs) { _ in "other text" }.isEmpty)
    }

    @Test func renamedAndClosedTabsUseTheCurrentCorpus() {
        let original = entry("Shell")
        let renamed = SidebarTabSearch.Entry(id: original.id, workspaceID: workspaceID, title: "Database")
        #expect(search.nameMatches(query: "Database", entries: [original]).isEmpty)
        #expect(search.nameMatches(query: "Database", entries: [renamed]) == [renamed])
        #expect(search.nameMatches(query: "Database", entries: []).isEmpty)
    }
}
