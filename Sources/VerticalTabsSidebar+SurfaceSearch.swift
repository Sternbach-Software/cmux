import CmuxSidebar
import SwiftUI

extension VerticalTabsSidebar {
    func refreshSidebarTabs() {
        sidebarTabBrowser.replaceFocusedPanels(Dictionary(uniqueKeysWithValues: tabManager.tabs.compactMap { workspace in
            workspace.focusedPanelId.map { (workspace.id, $0) }
        }))
        sidebarTabBrowser.replaceEntries(tabManager.tabs.flatMap { workspace in
            workspace.sidebarOrderedPanelIds().compactMap { panelID in
                guard let panel = workspace.panels[panelID] else { return nil }
                return SidebarTabSearch.Entry(
                    id: panelID,
                    workspaceID: workspace.id,
                    title: workspace.panelTitle(panelId: panelID) ?? panel.displayTitle,
                    icon: panel.displayIcon,
                    isPinned: workspace.isPanelPinned(panelID)
                )
            }
        })
    }

    func sidebarTabContent(_ entry: SidebarTabSearch.Entry) -> String? {
        guard let workspace = tabManager.tabs.first(where: { $0.id == entry.workspaceID }),
              let panel = workspace.panels[entry.id] else { return nil }
        if let terminal = panel as? TerminalPanel {
            // Ghostty's history can exclude the active screen. Use the same
            // complete text capture as `cmux read-screen --scrollback`.
            guard let snapshot = TerminalController.shared.readTerminalTextRawSnapshot(
                terminalSurface: terminal.surface,
                includeScrollback: true
            ), case .success(let payload) = TerminalController.terminalTextPayload(
                from: snapshot,
                includeScrollback: true,
                lineLimit: nil
            ) else { return nil }
            return payload.text
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
        // A search field's editor otherwise makes terminal focus restoration
        // intentionally back off, even after the target tab is selected.
        _ = observedWindow?.makeFirstResponder(nil)
        AppDelegate.shared?.noteMainPanelKeyboardFocusIntent(
            workspaceId: workspaceID,
            panelId: panelID,
            in: observedWindow
        )
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
