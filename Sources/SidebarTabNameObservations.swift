import Combine
import Foundation
import SwiftUI

extension View {
    /// Bridges tab titles, membership, pin state and pane order above the lazy row boundary.
    func sidebarTabNameObservations(
        ids: [UUID],
        workspaces: [Workspace],
        onChange: @MainActor @escaping () -> Void
    ) -> some View {
        task(id: ids) { @MainActor in
            await withTaskGroup(of: Void.self) { group in
                for workspace in workspaces {
                    let names = workspace.$panelTitles
                        .combineLatest(workspace.$panelCustomTitles, workspace.panelsPublisher)
                        .combineLatest(workspace.$pinnedPanelIds, workspace.paneLayoutVersionPublisher)
                        .combineLatest(workspace.sidebarSurfaceRevisionPublisher, workspace.sidebarFocusedPanelPublisher)
                        // Agent title and focus changes can arrive in bursts. Rebuild the
                        // sidebar projection at most once per display interval instead of
                        // publishing every intermediate value on the main actor.
                        .throttle(for: .milliseconds(50), scheduler: RunLoop.main, latest: true)
                        .values
                    group.addTask { @MainActor in
                        for await _ in names {
                            if Task.isCancelled { break }
                            onChange()
                        }
                    }
                }
            }
        }
    }
}
