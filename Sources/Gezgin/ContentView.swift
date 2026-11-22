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
                    Label("Geri", systemImage: "chevron.left")
                }
                .disabled(!model.canGoBack)
                .help("Geri")

                Button { model.goForward() } label: {
                    Label("İleri", systemImage: "chevron.right")
                }
                .disabled(!model.canGoForward)
                .help("İleri")

                Button { model.goUp() } label: {
                    Label("Yukarı", systemImage: "arrow.up")
                }
                .disabled(!model.canGoUp)
                .help("Üst klasör")
            }

            ToolbarItemGroup(placement: .primaryAction) {
                Button { model.beginNewFolder() } label: {
                    Label("Yeni Klasör", systemImage: "folder.badge.plus")
                }
                .help("Yeni klasör")

                Button { model.cutSelection() } label: {
                    Label("Kes", systemImage: "scissors")
                }
                .disabled(model.selection.isEmpty)
                .help("Kes")

                Button { model.copySelection() } label: {
                    Label("Kopyala", systemImage: "doc.on.doc")
                }
                .disabled(model.selection.isEmpty)
                .help("Kopyala")

                Button { model.paste() } label: {
                    Label("Yapıştır", systemImage: "doc.on.clipboard")
                }
                .help("Yapıştır")

                Button { model.trashSelection() } label: {
                    Label("Sil", systemImage: "trash")
                }
                .disabled(model.selection.isEmpty)
                .help("Çöp Kutusuna taşı")

                Button { model.openInTerminal(model.currentFolder) } label: {
                    Label("Terminal", systemImage: "terminal")
                }
                .help("Bu klasörde Terminal aç")

                Toggle(isOn: $model.showHidden) {
                    Label("Gizli Dosyalar", systemImage: "eye")
                }
                .help("Gizli dosyaları göster")

                Button { model.reload(); model.refreshTreeRoots(); model.treeRevision += 1 } label: {
                    Label("Yenile", systemImage: "arrow.clockwise")
                }
                .help("Yenile")
            }
        }
        .searchable(text: $model.searchText, prompt: "Bu klasörde ara")
        .quickLookPreview($model.quickLookURL)
        .alert("Yeniden Adlandır", isPresented: $model.showRename) {
            TextField("Ad", text: $model.nameInput)
            Button("Vazgeç", role: .cancel) {}
            Button("Tamam") { model.commitRename() }
        }
        .alert("Yeni Klasör", isPresented: $model.showNewFolder) {
            TextField("Klasör adı", text: $model.nameInput)
            Button("Vazgeç", role: .cancel) {}
            Button("Oluştur") { model.commitNewFolder() }
        }
        .alert("Yeni Metin Belgesi", isPresented: $model.showNewFile) {
            TextField("Dosya adı", text: $model.nameInput)
            Button("Vazgeç", role: .cancel) {}
            Button("Oluştur") { model.commitNewFile() }
        }
        .alert("Klasöre Git", isPresented: $model.showGoTo) {
            TextField("Yol", text: $model.nameInput)
            Button("Vazgeç", role: .cancel) {}
            Button("Git") { model.commitGoTo() }
        }
        .alert("Taşı veya Kopyala", isPresented: $model.showDropConfirm) {
            Button("Taşı") { model.performDrop(move: true) }
            Button("Kopyala") { model.performDrop(move: false) }
            Button("Vazgeç", role: .cancel) { model.cancelDrop() }
        } message: {
            Text(model.dropMessage)
        }
        .alert("Hata", isPresented: errorBinding) {
            Button("Tamam", role: .cancel) {}
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
            Button("Yolu Kopyala") { model.copyPath([]) }
            Button("Klasöre Git…") { model.beginGoTo() }
            Divider()
            Toggle("Tam Yolu Göster", isOn: $model.showFullPath)
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
