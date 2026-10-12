import CmuxSidebar
import SwiftUI

extension VerticalTabsSidebar {
    func refreshSidebarTabs() {
        sidebarTabBrowser.replaceEntries(tabManager.tabs.flatMap { workspace in
            workspace.sidebarOrderedPanelIds().compactMap { panelID in
                guard let panel = workspace.panels[panelID] else { return nil }
                return SidebarTabSearch.Entry(
                    id: panelID,
                    workspaceID: workspace.id,
                    title: workspace.panelTitle(panelId: panelID) ?? panel.displayTitle,
                    icon: panel.displayIcon
                )
            }
        })
    }

    func sidebarTabContent(_ entry: SidebarTabSearch.Entry) -> String? {
        guard let workspace = tabManager.tabs.first(where: { $0.id == entry.workspaceID }),
              let panel = workspace.panels[entry.id] else { return nil }
        if let terminal = panel as? TerminalPanel {
            return terminal.surface.readText(region: .history)
        }
        if let markdown = panel as? MarkdownPanel {
            return markdown.displayMode == .text ? markdown.textContent : markdown.content
        }
        return nil
    }

    func focusSidebarTab(_ panelID: UUID, workspaceID: UUID) {
        guard let workspace = tabManager.tabs.first(where: { $0.id == workspaceID }),
              workspace.panels[panelID] != nil else { return }
        selection = .tabs
        selectedTabIds = [workspaceID]
        lastSidebarSelectionIndex = tabManager.tabs.firstIndex(where: { $0.id == workspaceID })
        tabManager.focusTab(
            workspaceID,
            surfaceId: panelID,
            suppressFlash: true,
            dismissRestoredUnreadOnResume: true
        )
    }

    var sidebarTabSearchField: some View {
        @Bindable var browser = sidebarTabBrowser
        return SidebarSearchFieldView(
            text: $browser.query,
            placeholder: String(localized: "sidebar.tabs.search", defaultValue: "Search tabs"),
            accessibilityIdentifier: "sidebarTabSearch",
            onSubmit: focusFirstSidebarTabMatch,
            onCommandSubmit: focusFirstSidebarTabMatch
        )
        .frame(height: SidebarSearchField.visibleHeight)
        .padding(.horizontal, 10)
    }

    private func focusFirstSidebarTabMatch() {
        guard let match = sidebarTabBrowser.matches.first else { return }
        focusSidebarTab(match.id, workspaceID: match.workspaceID)
    }
}
