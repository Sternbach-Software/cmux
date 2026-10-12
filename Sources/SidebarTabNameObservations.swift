import Combine
import Foundation
import SwiftUI

extension View {
    /// Bridges existing workspace title publishers above the lazy row boundary.
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
