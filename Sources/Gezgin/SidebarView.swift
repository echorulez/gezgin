import AppKit
import SwiftUI

/// Sol panel: Windows Explorer tarzı klasör ağacı.
struct SidebarView: View {
    @EnvironmentObject var model: ExplorerModel

    var body: some View {
        let rows = model.treeRows
        let currentID = model.currentTreeRowID
        ScrollViewReader { proxy in
            // Bilerek List değil: List (NSTableView) satırlardaki sürükle-bırakı engelleyebiliyor.
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(rows) { row in
                        TreeRowView(row: row, isCurrent: row.id == currentID)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .contentShape(Rectangle())
            .onTapGesture { model.treeFocused = true }
            .onChange(of: currentID) { _, id in
                if let id { proxy.scrollTo(id) }
            }
        }
    }
}

struct TreeRowView: View {
    @EnvironmentObject var model: ExplorerModel
    let row: TreeRow
    let isCurrent: Bool
    @State private var dropTargeted = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: row.isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 16, height: 18)
                .contentShape(Rectangle())
                .opacity(row.hasChildren ? 1 : 0)
                .onTapGesture { model.toggleExpanded(row) }

            if row.depth <= 1 {
                // Bu Mac, ana klasör ve diskler kendi sistem ikonlarıyla kalır.
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
            } else {
                ItemIcon(themed: model.useThemeIcons, url: row.url, name: row.url.lastPathComponent, isDirectory: true,
                         isPackage: false, size: 16)
            }

            Text(row.isComputer ? L("Bu Mac") : FileManager.default.displayName(atPath: row.url.path))
                .lineLimit(1)

            Spacer(minLength: 0)

            if row.isVolume {
                Button {
                    model.eject(row.url)
                } label: {
                    Image(systemName: "eject.fill")
                        .font(.system(size: 10))
                }
                .buttonStyle(.borderless)
                .help(L("Çıkar"))
            }
        }
        .padding(.leading, CGFloat(row.depth) * 14)
        .padding(.vertical, 2)
        .padding(.trailing, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(highlight)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.accentColor, lineWidth: dropTargeted ? 2 : 0)
        )
        .contentShape(Rectangle())
        .onTapGesture { model.selectTreeRow(row) }
        .simultaneousGesture(TapGesture(count: 2).onEnded { model.toggleExpanded(row) })
        .onDrag {
            // Bu Mac, ana klasör ve diskler sürüklenemez.
            row.depth > 1 ? NSItemProvider(object: row.url as NSURL) : NSItemProvider()
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard !row.isComputer else { return false }
            model.requestDrop(urls, into: row.url)
            return true
        } isTargeted: { targeted in
            dropTargeted = targeted && !row.isComputer
        }
        .contextMenu {
            Button(row.isExpanded ? L("Daralt") : L("Genişlet")) { model.toggleExpanded(row) }
            if !row.isComputer {
                treeFolderMenu
            }
        }
        .id(row.id)
    }

    private var icon: NSImage {
        if row.isComputer {
            return NSImage(named: NSImage.computerName) ?? NSImage()
        }
        return NSWorkspace.shared.icon(forFile: row.url.path)
    }

    @ViewBuilder
    private var treeFolderMenu: some View {
        Group {
            Button(L("Aç")) { model.selectTreeRow(row) }
            Button(L("Buraya Yapıştır")) { model.paste(into: row.url) }
                .disabled(!model.pasteboardHasFiles)
            Divider()
            Button(L("Yolu Kopyala")) { model.copyPath([row.url]) }
            Button(L("Finder'da Göster")) { model.revealInFinder([row.url]) }
            Button(L("Burada Terminal Aç")) { model.openInTerminal(row.url) }
            if row.isVolume {
                Divider()
                Button(L("Çıkar")) { model.eject(row.url) }
            }
        }
    }

    private var highlight: Color {
        guard isCurrent else { return Color.clear }
        return model.treeFocused ? Color.accentColor.opacity(0.35) : Color.primary.opacity(0.1)
    }
}
