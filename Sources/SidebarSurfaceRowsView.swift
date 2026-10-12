import CmuxSidebar
import SwiftUI

/// Renders tab values and action closures without retaining a workspace store.
struct SidebarSurfaceRowsView: View {
    let tabs: [SidebarTabSearch.Entry]
    let selectedPanelID: UUID?
    let matchedByContent: Bool
    let fontSize: CGFloat
    let select: (UUID) -> Void

    var body: some View {
        VStack(spacing: 2) {
            ForEach(tabs) { tab in
                Button {
                    select(tab.id)
                } label: {
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
                    }
                    .cmuxFont(size: fontSize)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(tab.id == selectedPanelID ? Color.accentColor.opacity(0.18) : Color.clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(tab.title)
                .accessibilityIdentifier("sidebarSurface.\(tab.id.uuidString)")
                .accessibilityAddTraits(tab.id == selectedPanelID ? .isSelected : [])
            }
        }
        .padding(.leading, 22)
        .padding(.trailing, 8)
        .padding(.bottom, 4)
    }
}
