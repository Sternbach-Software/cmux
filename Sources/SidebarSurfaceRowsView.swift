import AppKit
import CmuxSidebar
import SwiftUI
import UniformTypeIdentifiers

/// Renders tab values and action closures without retaining a workspace store.
struct SidebarSurfaceRowsView: View {
    let tabs: [SidebarTabSearch.Entry]
    let selectedPanelID: UUID?
    let matchedByContent: Bool
    let fontSize: CGFloat
    let select: (UUID) -> Void
    let canReorder: (UUID, UUID) -> Bool
    let reorder: (UUID, UUID, SidebarSurfaceOrder.Placement) -> Bool

    var body: some View {
        let firstUnpinnedID = tabs.contains(where: \.isPinned) ? tabs.first(where: { !$0.isPinned })?.id : nil
        VStack(spacing: 2) {
            ForEach(tabs) { tab in
                if tab.id == firstUnpinnedID {
                    Divider().padding(.vertical, 3)
                }
                SidebarSurfaceRow(
                    tab: tab,
                    isSelected: tab.id == selectedPanelID,
                    matchedByContent: matchedByContent,
                    fontSize: fontSize,
                    select: { select(tab.id) },
                    canReorder: canReorder,
                    reorder: reorder
                )
            }
        }
        .padding(.leading, 22)
        .padding(.trailing, 8)
        .padding(.bottom, 4)
    }
}

private struct SidebarSurfaceRow: View {
    let tab: SidebarTabSearch.Entry
    let isSelected: Bool
    let matchedByContent: Bool
    let fontSize: CGFloat
    let select: () -> Void
    let canReorder: (UUID, UUID) -> Bool
    let reorder: (UUID, UUID, SidebarSurfaceOrder.Placement) -> Bool
    @State private var rowHeight: CGFloat = 28
    @State private var dropPlacement: SidebarSurfaceOrder.Placement?

    var body: some View {
        Button(action: select) {
            HStack(spacing: 7) {
                Image(systemName: tab.icon ?? "terminal")
                    .frame(width: 14)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: tab.title)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if matchedByContent {
                        Text(String(localized: "sidebar.tabs.contentMatch", defaultValue: "Content match"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                if tab.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
            .cmuxFont(size: fontSize)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(tab.title)
        .accessibilityIdentifier("sidebarSurface.\(tab.id.uuidString)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityValue(tab.isPinned ? String(localized: "taskManager.row.pinned", defaultValue: "Pinned") : "")
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { rowHeight = $0 }
        .overlay(alignment: dropPlacement == .after ? .bottom : .top) {
            if dropPlacement != nil {
                Capsule().fill(Color.accentColor).frame(height: 2).allowsHitTesting(false)
            }
        }
        .onDrag { SidebarSurfaceDragPayload.provider(panelID: tab.id) }
        .onDrop(of: [SidebarSurfaceDragPayload.contentType], delegate: SidebarSurfaceDropDelegate(
            targetID: tab.id,
            rowHeight: rowHeight,
            placement: $dropPlacement,
            canReorder: canReorder,
            reorder: reorder
        ))
    }
}

/// Uses a distinct type so surface drags never trigger workspace moves or pane transfers.
private enum SidebarSurfaceDragPayload {
    static let typeIdentifier = "com.cmux.sidebar-surface-reorder"
    static let contentType = UTType(exportedAs: typeIdentifier)

    static func provider(panelID: UUID) -> NSItemProvider {
        let provider = NSItemProvider()
        let data = Data(panelID.uuidString.utf8)
        provider.registerDataRepresentation(forTypeIdentifier: typeIdentifier, visibility: .ownProcess) { completion in
            completion(data, nil)
            return nil
        }
        return provider
    }

    static func draggedPanelID() -> UUID? {
        let pasteboard = NSPasteboard(name: .drag)
        let type = NSPasteboard.PasteboardType(typeIdentifier)
        guard let value = pasteboard.string(forType: type)
            ?? pasteboard.data(forType: type).flatMap({ String(data: $0, encoding: .utf8) }) else { return nil }
        return UUID(uuidString: value)
    }
}

@MainActor
private struct SidebarSurfaceDropDelegate: DropDelegate {
    let targetID: UUID
    let rowHeight: CGFloat
    @Binding var placement: SidebarSurfaceOrder.Placement?
    let canReorder: (UUID, UUID) -> Bool
    let reorder: (UUID, UUID, SidebarSurfaceOrder.Placement) -> Bool

    func validateDrop(info: DropInfo) -> Bool {
        sourceID(info: info) != nil
    }

    func dropEntered(info: DropInfo) {
        updatePlacement(info: info)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        updatePlacement(info: info)
        return DropProposal(operation: placement == nil ? .forbidden : .move)
    }

    func dropExited(info: DropInfo) {
        placement = nil
    }

    func performDrop(info: DropInfo) -> Bool {
        defer { placement = nil }
        guard let sourceID = sourceID(info: info) else { return false }
        return reorder(sourceID, targetID, proposedPlacement(info: info))
    }

    private func sourceID(info: DropInfo) -> UUID? {
        guard info.hasItemsConforming(to: [SidebarSurfaceDragPayload.typeIdentifier]),
              let id = SidebarSurfaceDragPayload.draggedPanelID(),
              canReorder(id, targetID) else { return nil }
        return id
    }

    private func updatePlacement(info: DropInfo) {
        placement = sourceID(info: info) == nil ? nil : proposedPlacement(info: info)
    }

    private func proposedPlacement(info: DropInfo) -> SidebarSurfaceOrder.Placement {
        info.location.y < rowHeight / 2 ? .before : .after
    }
}
