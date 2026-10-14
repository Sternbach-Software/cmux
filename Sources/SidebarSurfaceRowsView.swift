import CmuxSidebar
import SwiftUI

/// Renders tab values and action closures without retaining a workspace store.
struct SidebarSurfaceRowsView: View {
    let tabs: [SidebarTabSearch.Entry]
    let selectedPanelID: UUID?
    let matchedByContent: Bool
    let fontSize: CGFloat
    let select: (UUID) -> Void
    let rename: (UUID, String) -> Void
    let canReorder: (UUID, UUID) -> Bool
    let reorder: (UUID, UUID, SidebarSurfaceOrder.Placement) -> Bool

    @State private var rowFrames: [UUID: CGRect] = [:]
    @State private var dropTarget: (id: UUID, placement: SidebarSurfaceOrder.Placement)?

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
                    dropPlacement: dropTarget?.id == tab.id ? dropTarget?.placement : nil,
                    select: { select(tab.id) },
                    rename: { rename(tab.id, tab.title) },
                    frameChanged: { rowFrames[tab.id] = $0 },
                    dragChanged: { updateDropTarget(sourceID: tab.id, location: $0) },
                    dragEnded: { finishDrag(sourceID: tab.id, location: $0) }
                )
            }
        }
        .padding(.leading, 22)
        .padding(.trailing, 8)
        .padding(.bottom, 4)
        .coordinateSpace(name: "sidebarSurfaceRows")
    }

    private func target(sourceID: UUID, location: CGPoint) -> (id: UUID, placement: SidebarSurfaceOrder.Placement)? {
        guard let candidate = tabs.compactMap({ tab -> (UUID, CGRect)? in
            guard canReorder(sourceID, tab.id), let frame = rowFrames[tab.id] else { return nil }
            return (tab.id, frame)
        }).first(where: { $0.1.contains(location) }) else { return nil }
        return (candidate.0, location.y < candidate.1.midY ? .before : .after)
    }

    private func updateDropTarget(sourceID: UUID, location: CGPoint) {
        dropTarget = target(sourceID: sourceID, location: location)
    }

    private func finishDrag(sourceID: UUID, location: CGPoint) {
        defer { dropTarget = nil }
        guard let destination = target(sourceID: sourceID, location: location) else { return }
        _ = reorder(sourceID, destination.id, destination.placement)
    }
}

private struct SidebarSurfaceRow: View {
    let tab: SidebarTabSearch.Entry
    let isSelected: Bool
    let matchedByContent: Bool
    let fontSize: CGFloat
    let dropPlacement: SidebarSurfaceOrder.Placement?
    let select: () -> Void
    let rename: () -> Void
    let frameChanged: (CGRect) -> Void
    let dragChanged: (CGPoint) -> Void
    let dragEnded: (CGPoint) -> Void

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
        .contextMenu {
            Button(
                String(localized: "command.renameTab.title", defaultValue: "Rename Tab…"),
                action: rename
            )
        }
        .accessibilityIdentifier("sidebarSurface.\(tab.id.uuidString)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityValue(tab.isPinned ? String(localized: "taskManager.row.pinned", defaultValue: "Pinned") : "")
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("sidebarSurfaceRows")) } action: { frameChanged($0) }
        .overlay(alignment: dropPlacement == .after ? .bottom : .top) {
            if dropPlacement != nil {
                Capsule().fill(Color.accentColor).frame(height: 2).allowsHitTesting(false)
            }
        }
        .simultaneousGesture(
            TapGesture(count: 2).onEnded(rename)
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 6, coordinateSpace: .named("sidebarSurfaceRows"))
                .onChanged { dragChanged($0.location) }
                .onEnded { dragEnded($0.location) }
        )
    }
}
