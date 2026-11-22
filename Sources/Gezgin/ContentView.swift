import QuickLook
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var model: ExplorerModel

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 180, ideal: 250, max: 420)
        } detail: {
            VStack(spacing: 0) {
                PathBar()
                Divider()
                FileListView()
                Divider()
                StatusBar()
            }
        }
        .navigationTitle(model.currentTitle)
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button { model.goBack() } label: {
                    Label(L("Geri"), systemImage: "chevron.left")
                }
                .disabled(!model.canGoBack)
                .help(L("Geri"))

                Button { model.goForward() } label: {
                    Label(L("İleri"), systemImage: "chevron.right")
                }
                .disabled(!model.canGoForward)
                .help(L("İleri"))

                Button { model.goUp() } label: {
                    Label(L("Yukarı"), systemImage: "arrow.up")
                }
                .disabled(!model.canGoUp)
                .help(L("Üst klasör"))
            }

            ToolbarItemGroup(placement: .primaryAction) {
                Button { model.beginNewFolder() } label: {
                    Label(L("Yeni Klasör"), systemImage: "folder.badge.plus")
                }
                .help(L("Yeni klasör"))

                Button { model.cutSelection() } label: {
                    Label(L("Kes"), systemImage: "scissors")
                }
                .disabled(model.selection.isEmpty)
                .help(L("Kes"))

                Button { model.copySelection() } label: {
                    Label(L("Kopyala"), systemImage: "doc.on.doc")
                }
                .disabled(model.selection.isEmpty)
                .help(L("Kopyala"))

                Button { model.paste() } label: {
                    Label(L("Yapıştır"), systemImage: "doc.on.clipboard")
                }
                .help(L("Yapıştır"))

                Button { model.trashSelection() } label: {
                    Label(L("Sil"), systemImage: "trash")
                }
                .disabled(model.selection.isEmpty)
                .help(L("Çöp Kutusuna taşı"))

                Button { model.openInTerminal(model.currentFolder) } label: {
                    Label(L("Terminal"), systemImage: "terminal")
                }
                .help(L("Bu klasörde Terminal aç"))

                Toggle(isOn: $model.showHidden) {
                    Label(L("Gizli Dosyalar"), systemImage: "eye")
                }
                .help(L("Gizli dosyaları göster"))

                Button { model.reload(); model.refreshTreeRoots(); model.treeRevision += 1 } label: {
                    Label(L("Yenile"), systemImage: "arrow.clockwise")
                }
                .help(L("Yenile"))
            }
        }
        .searchable(text: $model.searchText, prompt: L("Bu klasörde ara"))
        .quickLookPreview($model.quickLookURL)
        .alert(L("Yeniden Adlandır"), isPresented: $model.showRename) {
            TextField(L("Ad"), text: $model.nameInput)
            Button(L("Vazgeç"), role: .cancel) {}
            Button(L("Tamam")) { model.commitRename() }
        }
        .alert(L("Yeni Klasör"), isPresented: $model.showNewFolder) {
            TextField(L("Klasör adı"), text: $model.nameInput)
            Button(L("Vazgeç"), role: .cancel) {}
            Button(L("Oluştur")) { model.commitNewFolder() }
        }
        .alert(L("Yeni Metin Belgesi"), isPresented: $model.showNewFile) {
            TextField(L("Dosya adı"), text: $model.nameInput)
            Button(L("Vazgeç"), role: .cancel) {}
            Button(L("Oluştur")) { model.commitNewFile() }
        }
        .alert(L("Klasöre Git"), isPresented: $model.showGoTo) {
            TextField(L("Yol"), text: $model.nameInput)
            Button(L("Vazgeç"), role: .cancel) {}
            Button(L("Git")) { model.commitGoTo() }
        }
        .alert(L("Taşı veya Kopyala"), isPresented: $model.showDropConfirm) {
            Button(L("Taşı")) { model.performDrop(move: true) }
            Button(L("Kopyala")) { model.performDrop(move: false) }
            Button(L("Vazgeç"), role: .cancel) { model.cancelDrop() }
        } message: {
            Text(model.dropMessage)
        }
        .alert(L("Hata"), isPresented: errorBinding) {
            Button(L("Tamam"), role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { model.errorMessage != nil },
            set: { shown in
                if !shown { model.errorMessage = nil }
            }
        )
    }
}

/// Tıklanabilir adres çubuğu.
struct PathBar: View {
    @EnvironmentObject var model: ExplorerModel

    var body: some View {
        let crumbs = model.pathCrumbs
        ScrollView(.horizontal, showsIndicators: false) {
            if model.showFullPath {
                // Tam yol: /Users/ekrem/Projects — her parça tıklanabilir.
                HStack(spacing: 0) {
                    ForEach(Array(crumbs.enumerated()), id: \.offset) { index, crumb in
                        if index > 1 {
                            Text("/")
                                .foregroundStyle(.tertiary)
                        }
                        Button {
                            model.navigate(to: crumb.url)
                        } label: {
                            Text(crumb.component)
                                .lineLimit(1)
                                .padding(.horizontal, 2)
                                .padding(.vertical, 3)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .fontWeight(index == crumbs.count - 1 ? .semibold : .regular)
                    }
                }
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 10)
            } else {
                HStack(spacing: 2) {
                    ForEach(Array(crumbs.enumerated()), id: \.offset) { index, crumb in
                        if index > 0 {
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Button {
                            model.navigate(to: crumb.url)
                        } label: {
                            Text(crumb.title)
                                .lineLimit(1)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 3)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .fontWeight(index == crumbs.count - 1 ? .semibold : .regular)
                    }
                }
                .padding(.horizontal, 10)
            }
        }
        .frame(height: 30)
        .background(.bar)
        .contextMenu {
            Button(L("Yolu Kopyala")) { model.copyPath([]) }
            Button(L("Klasöre Git…")) { model.beginGoTo() }
            Divider()
            Toggle(L("Tam Yolu Göster"), isOn: $model.showFullPath)
        }
    }
}

struct StatusBar: View {
    @EnvironmentObject var model: ExplorerModel

    var body: some View {
        HStack(spacing: 8) {
            Text(model.statusText)
            if model.busy {
                ProgressView()
                    .controlSize(.small)
            }
            Spacer()
            Text(model.freeSpaceText)
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .frame(height: 26)
        .background(.bar)
    }
}
