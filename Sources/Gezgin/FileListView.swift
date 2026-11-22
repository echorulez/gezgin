import AppKit
import SwiftUI

struct FileListView: View {
    @EnvironmentObject var model: ExplorerModel

    var body: some View {
        Table(of: FileItem.self, selection: $model.selection, sortOrder: $model.sortOrder) {
            TableColumn("Ad", value: \.name) { item in
                HStack(spacing: 6) {
                    Image(nsImage: item.icon)
                        .resizable()
                        .frame(width: 18, height: 18)
                    Text(item.name)
                        .lineLimit(1)
                }
                .opacity(model.cutURLs.contains(item.url) || item.isHidden ? 0.5 : 1)
            }
            .width(min: 180, ideal: 340)

            TableColumn("Değiştirilme", value: \.modified) { item in
                Text(item.modified.formatted(date: .abbreviated, time: .shortened))
                    .foregroundStyle(.secondary)
            }
            .width(min: 120, ideal: 160)

            TableColumn("Boyut", value: \.size) { item in
                Text(item.sizeText)
                    .foregroundStyle(.secondary)
            }
            .width(min: 60, ideal: 90)

            TableColumn("Tür", value: \.kind) { item in
                Text(item.kind)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .width(min: 100, ideal: 180)
        } rows: {
            ForEach(model.items) { item in
                TableRow(item)
                    .itemProvider { NSItemProvider(object: item.url as NSURL) }
                    .dropDestination(for: URL.self) { urls in
                        // Klasörün üstüne bırakılırsa içine, değilse görüntülenen klasöre.
                        model.requestDrop(urls, into: item.isDirectory ? item.url : model.currentFolder)
                    }
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            model.requestDrop(urls, into: model.currentFolder)
            return true
        }
        .contextMenu(forSelectionType: URL.self) { ids in
            ItemContextMenu(model: model, ids: ids)
        } primaryAction: { ids in
            model.openItems(Array(ids))
        }
        .overlay {
            if model.items.isEmpty {
                Text(emptyMessage)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                    .allowsHitTesting(false)
            }
        }
    }

    private var emptyMessage: String {
        if let error = model.folderError { return error }
        if !model.searchText.isEmpty { return "Eşleşen öğe yok" }
        return "Bu klasör boş"
    }
}

/// Sağ tık menüsü: öğe(ler) üzerinde veya boş alanda.
struct ItemContextMenu: View {
    @ObservedObject var model: ExplorerModel
    let ids: Set<URL>

    var body: some View {
        let urls = Array(ids)
        if urls.isEmpty {
            Button("Yeni Klasör") { model.beginNewFolder() }
            Button("Yeni Metin Belgesi") { model.beginNewFile() }
            Divider()
            Button("Yapıştır") { model.paste() }
                .disabled(!model.pasteboardHasFiles)
            Divider()
            Button("Yolu Kopyala") { model.copyPath([]) }
            Button("Finder'da Göster") { model.revealInFinder([]) }
            Button("Burada Terminal Aç") { model.openInTerminal(model.currentFolder) }
            Divider()
            Button("Yenile") { model.reload() }
        } else {
            Button("Aç") { model.openItems(urls) }
            if urls.count == 1, let url = urls.first {
                let apps = model.applications(for: url)
                if !apps.isEmpty {
                    Menu("Birlikte Aç") {
                        ForEach(apps, id: \.path) { app in
                            Button(FileManager.default.displayName(atPath: app.path)) {
                                model.open(url, withApplication: app)
                            }
                        }
                    }
                }
            }
            Divider()
            Button("Kes") { model.cut(urls) }
            Button("Kopyala") { model.copy(urls) }
            if urls.count == 1, let url = urls.first, isFolder(url) {
                Button("İçine Yapıştır") { model.paste(into: url) }
                    .disabled(!model.pasteboardHasFiles)
            }
            Button("Çoğalt") { model.duplicate(urls) }
            Divider()
            if urls.count == 1, let url = urls.first {
                Button("Yeniden Adlandır…") { model.beginRename(url) }
            }
            Button("Çöp Kutusuna Taşı") { model.trash(urls) }
            Divider()
            Button("Yolu Kopyala") { model.copyPath(urls) }
            Button("Finder'da Göster") { model.revealInFinder(urls) }
            if urls.count == 1, let url = urls.first, isFolder(url) {
                Button("Burada Terminal Aç") { model.openInTerminal(url) }
            }
        }
    }

    private func isFolder(_ url: URL) -> Bool {
        model.items.first { $0.id == url }?.isDirectory ?? false
    }
}
