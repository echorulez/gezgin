import AppKit
import SwiftUI

/// Uygulamanın tüm durumu ve dosya işlemleri.
final class ExplorerModel: ObservableObject {

    // MARK: - Durum

    @Published var currentFolder: URL
    @Published var items: [FileItem] = []
    @Published var selection = Set<URL>()
    @Published var sortOrder: [KeyPathComparator<FileItem>] = [
        KeyPathComparator(\FileItem.name, comparator: .localizedStandard)
    ] {
        didSet { applySortAndFilter() }
    }
    @Published var showHidden = false {
        didSet {
            reload()
            treeRevision += 1
        }
    }
    /// Adres çubuğunda tam yol (/Users/…) mu, yoksa görünen adlar mı gösterilsin.
    @Published var showFullPath: Bool = (UserDefaults.standard.object(forKey: "showFullPath") as? Bool) ?? true {
        didSet { UserDefaults.standard.set(showFullPath, forKey: "showFullPath") }
    }
    @Published var searchText = "" {
        didSet { applySortAndFilter() }
    }

    @Published var folderError: String?
    @Published var errorMessage: String?
    @Published var busy = false
    @Published var freeSpaceText = ""

    @Published var showRename = false
    @Published var showNewFolder = false
    @Published var showNewFile = false
    @Published var showGoTo = false
    @Published var nameInput = ""

    @Published var quickLookURL: URL?
    @Published var cutURLs = Set<URL>()
    /// Değiştiğinde soldaki ağaç açık düğümlerini yeniden okur.
    @Published var treeRevision = 0 {
        didSet { refreshTree() }
    }

    // Ağaç durumu
    @Published var expandedRows = Set<String>()
    @Published var childrenCache: [String: [URL]] = [:]
    /// Klavye ağaçta mı (true) yoksa dosya listesinde mi (false)?
    @Published var treeFocused = false
    @Published var treeSelectionID: String?

    // Sürükle-bırak onayı
    @Published var showDropConfirm = false
    @Published var pendingDropSources: [URL] = []
    @Published var pendingDropTarget: URL?

    @Published private(set) var backStack: [URL] = []
    @Published private(set) var forwardStack: [URL] = []

    let favorites: [Favorite]
    @Published var treeRoots: [URL] = []

    private var allItems: [FileItem] = []
    private var renameURL: URL?
    private var cutChangeCount = -1
    private var loadGeneration = 0
    private var pendingSelectPaths = Set<String>()
    private var keyMonitor: Any?
    private var mouseMonitor: Any?
    private var volumeObservers: [NSObjectProtocol] = []
    private var watcher: DispatchSourceFileSystemObject?
    private var reloadWork: DispatchWorkItem?

    // MARK: - Kurulum

    init() {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        currentFolder = home

        var favs = [Favorite(title: "Ana Klasör", systemImage: "house", url: home)]
        let known: [(String, String, FileManager.SearchPathDirectory)] = [
            ("Masaüstü", "menubar.dock.rectangle", .desktopDirectory),
            ("Belgeler", "doc", .documentDirectory),
            ("İndirilenler", "arrow.down.circle", .downloadsDirectory)
        ]
        for (title, image, dir) in known {
            if let url = fm.urls(for: dir, in: .userDomainMask).first {
                favs.append(Favorite(title: title, systemImage: image, url: url))
            }
        }
        favs.append(Favorite(title: "Uygulamalar", systemImage: "square.grid.2x2",
                             url: URL(fileURLWithPath: "/Applications")))
        favorites = favs

        refreshTreeRoots()
        loadChildren(home.path)
        expandedRows.insert(ExplorerModel.rowID(home.path, home.path))
        expandedRows.insert(ExplorerModel.computerRowID)
        installKeyMonitor()
        installMouseMonitor()
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didMountNotification, NSWorkspace.didUnmountNotification] {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.refreshTreeRoots()
            }
            volumeObservers.append(token)
        }
        startWatching()
        reload()
    }

    deinit {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
        for token in volumeObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(token)
        }
        watcher?.cancel()
    }

    func refreshTreeRoots() {
        let fm = FileManager.default
        var roots = [fm.homeDirectoryForCurrentUser, URL(fileURLWithPath: "/")]
        let volumes = fm.mountedVolumeURLs(includingResourceValuesForKeys: nil,
                                           options: [.skipHiddenVolumes]) ?? []
        for volume in volumes where volume.path != "/" {
            roots.append(volume)
        }
        treeRoots = roots
    }

    // MARK: - Türetilmiş değerler

    var canGoBack: Bool { !backStack.isEmpty }
    var canGoForward: Bool { !forwardStack.isEmpty }
    var canGoUp: Bool { currentFolder.path != "/" }

    var currentTitle: String {
        FileManager.default.displayName(atPath: currentFolder.path)
    }

    var pathCrumbs: [PathCrumb] {
        var crumbs: [PathCrumb] = []
        var url = URL(fileURLWithPath: "/")
        for (index, component) in currentFolder.pathComponents.enumerated() {
            if index == 0 {
                crumbs.append(PathCrumb(title: FileManager.default.displayName(atPath: "/"), url: url, component: "/"))
            } else {
                url = url.appendingPathComponent(component)
                crumbs.append(PathCrumb(title: FileManager.default.displayName(atPath: url.path), url: url, component: component))
            }
        }
        return crumbs
    }

    var selectedItems: [FileItem] {
        items.filter { selection.contains($0.id) }
    }

    var statusText: String {
        var text = "\(items.count) öğe"
        let selected = selectedItems
        if !selected.isEmpty {
            text += " • \(selected.count) seçili"
            let total = selected.filter { !$0.isDirectory && !$0.isPackage }
                .reduce(Int64(0)) { $0 + $1.size }
            if total > 0 {
                text += " (" + ByteCountFormatter.string(fromByteCount: total, countStyle: .file) + ")"
            }
        }
        return text
    }

    var pasteboardHasFiles: Bool {
        !pasteboardFileURLs().isEmpty
    }

    // MARK: - Klasör ağacı

    static let computerRowID = "computer"

    static func rowID(_ root: String, _ path: String) -> String {
        root + "|" + path
    }

    /// Geçerli klasörü kapsayan en derin ağaç kökü.
    func bestRootPath() -> String {
        let current = currentFolder.path
        var best = ""
        for root in treeRoots {
            let path = root.path
            if ExplorerModel.isAncestorOrSame(path, of: current), path.count > best.count {
                best = path
            }
        }
        return best
    }

    /// Ağacın o an görünen satırları (açık düğümlerin altları dahil), yukarıdan aşağıya.
    var treeRows: [TreeRow] {
        var rows: [TreeRow] = []
        let home = FileManager.default.homeDirectoryForCurrentUser.path

        func visit(_ url: URL, root: String, depth: Int) {
            let path = url.path
            let id = ExplorerModel.rowID(root, path)
            let cached = childrenCache[path]
            let expanded = expandedRows.contains(id)
            rows.append(TreeRow(
                id: id,
                url: url,
                rootPath: root,
                depth: depth,
                isExpanded: expanded,
                hasChildren: cached.map { !$0.isEmpty } ?? true,
                isVolume: depth == 1 && path != "/" && path != home
            ))
            if expanded, let cached {
                for child in cached {
                    visit(child, root: root, depth: depth + 1)
                }
            }
        }

        // Tek kök: "Bu Mac". Ana klasör, Macintosh HD ve bağlı diskler onun altında.
        let computerExpanded = expandedRows.contains(ExplorerModel.computerRowID)
        rows.append(TreeRow(
            id: ExplorerModel.computerRowID,
            url: URL(fileURLWithPath: "/"),
            rootPath: "",
            depth: 0,
            isExpanded: computerExpanded,
            hasChildren: true,
            isVolume: false,
            isComputer: true
        ))
        if computerExpanded {
            for root in treeRoots {
                visit(root, root: root.path, depth: 1)
            }
        }
        return rows
    }

    /// Ağaçta vurgulanacak satır: geçerli klasöre karşılık gelen satır.
    var currentTreeRowID: String? {
        let rows = treeRows.filter { !$0.isComputer }
        let current = currentFolder.path
        if let selected = treeSelectionID,
           rows.contains(where: { $0.id == selected && $0.url.path == current }) {
            return selected
        }
        let best = bestRootPath()
        if let row = rows.first(where: { $0.rootPath == best && $0.url.path == current }) {
            return row.id
        }
        return rows.first(where: { $0.url.path == current })?.id
    }

    static func listSubfolders(_ path: String, showHidden: Bool) -> [URL] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey]
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: keys,
            options: showHidden ? [] : [.skipsHiddenFiles]
        )) ?? []
        return urls.filter { candidate in
            let values = try? candidate.resourceValues(forKeys: Set(keys))
            return (values?.isDirectory ?? false) && !(values?.isPackage ?? false)
        }
        .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    func loadChildren(_ path: String) {
        if childrenCache[path] == nil {
            childrenCache[path] = ExplorerModel.listSubfolders(path, showHidden: showHidden)
        }
    }

    /// Önbellekteki tüm açılmış klasörlerin alt klasörlerini yeniden okur.
    func refreshTree() {
        var updated: [String: [URL]] = [:]
        for path in childrenCache.keys {
            updated[path] = ExplorerModel.listSubfolders(path, showHidden: showHidden)
        }
        childrenCache = updated
    }

    func setExpanded(_ row: TreeRow, _ expanded: Bool) {
        if row.isComputer {
            if expanded {
                expandedRows.insert(row.id)
            } else {
                expandedRows.remove(row.id)
            }
            return
        }
        if expanded {
            loadChildren(row.url.path)
            expandedRows.insert(row.id)
        } else {
            expandedRows.remove(row.id)
            // Windows gibi: seçili klasör kapanan dalın içindeyse seçim o dala taşınır.
            if currentTreeRowID == nil {
                selectTreeRow(row)
            }
        }
    }

    func toggleExpanded(_ row: TreeRow) {
        setExpanded(row, !row.isExpanded)
    }

    func selectTreeRow(_ row: TreeRow) {
        treeFocused = true
        if row.isComputer {
            toggleExpanded(row)
            return
        }
        treeSelectionID = row.id
        navigate(to: row.url)
    }

    /// Geçerli klasör ağaçta görünsün diye üst klasörlerini açar.
    private func revealInTree() {
        let current = currentFolder.path
        let best = bestRootPath()
        if !expandedRows.contains(ExplorerModel.computerRowID) {
            expandedRows.insert(ExplorerModel.computerRowID)
        }
        guard !best.isEmpty, current != best else { return }
        var ancestors: [String] = []
        var path = current
        while path != best && path != "/" {
            path = (path as NSString).deletingLastPathComponent
            ancestors.append(path)
        }
        var expanded = expandedRows
        for ancestor in ancestors {
            loadChildren(ancestor)
            expanded.insert(ExplorerModel.rowID(best, ancestor))
        }
        if expanded != expandedRows { expandedRows = expanded }
    }

    func eject(_ url: URL) {
        if ExplorerModel.isAncestorOrSame(url.path, of: currentFolder.path) {
            navigate(to: FileManager.default.homeDirectoryForCurrentUser)
        }
        let name = FileManager.default.displayName(atPath: url.path)
        busy = true
        DispatchQueue.global(qos: .userInitiated).async {
            var failure: String?
            do {
                try NSWorkspace.shared.unmountAndEjectDevice(at: url)
            } catch {
                failure = error.localizedDescription
            }
            DispatchQueue.main.async {
                self.busy = false
                if let failure {
                    self.errorMessage = "“\(name)” çıkarılamadı.\n\(failure)"
                }
                self.refreshTreeRoots()
            }
        }
    }

    static func isAncestorOrSame(_ ancestor: String, of path: String) -> Bool {
        if ancestor == path { return true }
        if ancestor == "/" { return true }
        return path.hasPrefix(ancestor + "/")
    }

    // MARK: - Gezinme

    func navigate(to url: URL, recordHistory: Bool = true) {
        let target = url.standardizedFileURL
        if target.path == currentFolder.path {
            reload()
            return
        }
        if recordHistory {
            backStack.append(currentFolder)
            forwardStack.removeAll()
        }
        currentFolder = target
        if let selected = treeSelectionID, !selected.hasSuffix("|" + target.path) {
            treeSelectionID = nil
        }
        revealInTree()
        selection = []
        if !searchText.isEmpty { searchText = "" }
        startWatching()
        reload()
    }

    func goBack() {
        guard let previous = backStack.popLast() else { return }
        forwardStack.append(currentFolder)
        navigate(to: previous, recordHistory: false)
    }

    func goForward() {
        guard let next = forwardStack.popLast() else { return }
        backStack.append(currentFolder)
        navigate(to: next, recordHistory: false)
    }

    func goUp() {
        guard canGoUp else { return }
        let child = currentFolder
        navigate(to: currentFolder.deletingLastPathComponent())
        pendingSelectPaths = [child.path]
    }

    func beginGoTo() {
        nameInput = currentFolder.path
        showGoTo = true
    }

    func commitGoTo() {
        let raw = nameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }
        let path = (raw as NSString).expandingTildeInPath
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDir) {
            if isDir.boolValue {
                navigate(to: URL(fileURLWithPath: path))
            } else {
                let fileURL = URL(fileURLWithPath: path)
                navigate(to: fileURL.deletingLastPathComponent())
                pendingSelectPaths = [fileURL.path]
            }
        } else {
            errorMessage = "Böyle bir konum yok:\n\(path)"
        }
    }

    // MARK: - Listeleme

    func reload() {
        let folder = currentFolder
        let hidden = showHidden
        loadGeneration += 1
        let generation = loadGeneration

        DispatchQueue.global(qos: .userInitiated).async {
            var loaded: [FileItem] = []
            var failure: String?
            do {
                let urls = try FileManager.default.contentsOfDirectory(
                    at: folder,
                    includingPropertiesForKeys: FileItem.resourceKeys,
                    options: hidden ? [] : [.skipsHiddenFiles]
                )
                loaded = urls.map { FileItem(url: $0) }
            } catch {
                failure = error.localizedDescription
            }
            let values = try? folder.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            let free = values?.volumeAvailableCapacityForImportantUsage

            DispatchQueue.main.async {
                guard generation == self.loadGeneration else { return }
                self.allItems = loaded
                if failure == nil, self.childrenCache[folder.path] != nil {
                    let fresh = ExplorerModel.listSubfolders(folder.path, showHidden: hidden)
                    if self.childrenCache[folder.path]?.map({ $0.path }) != fresh.map({ $0.path }) {
                        self.childrenCache[folder.path] = fresh
                    }
                }
                self.folderError = failure
                if let free {
                    self.freeSpaceText = ByteCountFormatter.string(fromByteCount: free, countStyle: .file) + " boş"
                } else {
                    self.freeSpaceText = ""
                }
                self.applySortAndFilter()

                if !self.pendingSelectPaths.isEmpty {
                    let wanted = self.pendingSelectPaths
                    self.pendingSelectPaths = []
                    self.selection = Set(self.items.filter { wanted.contains($0.url.path) }.map { $0.id })
                } else {
                    let existing = Set(self.items.map { $0.id })
                    let kept = self.selection.intersection(existing)
                    if kept != self.selection { self.selection = kept }
                }
            }
        }
    }

    private func applySortAndFilter() {
        var list = allItems
        let query = searchText.trimmingCharacters(in: .whitespaces)
        if !query.isEmpty {
            list = list.filter { $0.name.localizedCaseInsensitiveContains(query) }
        }
        list.sort(using: sortOrder)
        // Explorer gibi: klasörler her zaman üstte.
        items = list.filter { $0.isDirectory } + list.filter { !$0.isDirectory }
    }

    private func scheduleReload() {
        reloadWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.reload()
        }
        reloadWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    /// Geçerli klasörü izler; dışarıdan değişirse listeyi yeniler.
    private func startWatching() {
        watcher?.cancel()
        watcher = nil
        let descriptor = Darwin.open(currentFolder.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .rename, .delete],
            queue: DispatchQueue.main
        )
        source.setEventHandler { [weak self] in
            self?.scheduleReload()
        }
        source.setCancelHandler {
            Darwin.close(descriptor)
        }
        source.resume()
        watcher = source
    }

    // MARK: - Açma

    func openSelection() {
        openItems(Array(selection))
    }

    func openItems(_ urls: [URL]) {
        let wanted = Set(urls)
        let targets = items.filter { wanted.contains($0.id) }
        if targets.count == 1, let only = targets.first, only.isDirectory {
            navigate(to: only.url)
            return
        }
        for item in targets where !item.isDirectory {
            if !NSWorkspace.shared.open(item.url) {
                errorMessage = "“\(item.name)” açılamadı."
            }
        }
    }

    func applications(for url: URL) -> [URL] {
        Array(NSWorkspace.shared.urlsForApplications(toOpen: url).prefix(15))
    }

    func open(_ url: URL, withApplication app: URL) {
        NSWorkspace.shared.open([url], withApplicationAt: app,
                                configuration: NSWorkspace.OpenConfiguration(),
                                completionHandler: nil)
    }

    func revealInFinder(_ urls: [URL]) {
        if urls.isEmpty {
            NSWorkspace.shared.activateFileViewerSelecting([currentFolder])
        } else {
            NSWorkspace.shared.activateFileViewerSelecting(urls)
        }
    }

    func openInTerminal(_ folder: URL) {
        let terminal = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
        NSWorkspace.shared.open([folder], withApplicationAt: terminal,
                                configuration: NSWorkspace.OpenConfiguration(),
                                completionHandler: nil)
    }

    func copyPath(_ urls: [URL]) {
        let list = urls.isEmpty ? [currentFolder] : urls
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(list.map { $0.path }.joined(separator: "\n"), forType: .string)
        cutURLs = []
    }

    func toggleQuickLook() {
        if quickLookURL != nil {
            quickLookURL = nil
        } else if let first = selectedItems.first {
            quickLookURL = first.url
        }
    }

    // MARK: - Pano (Finder ile ortak)

    func copySelection() { copy(Array(selection)) }
    func cutSelection() { cut(Array(selection)) }

    func copy(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        writeToPasteboard(urls)
        cutURLs = []
        cutChangeCount = -1
    }

    func cut(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        writeToPasteboard(urls)
        cutURLs = Set(urls)
        cutChangeCount = NSPasteboard.general.changeCount
    }

    private func writeToPasteboard(_ urls: [URL]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(urls.map { $0 as NSURL })
    }

    private func pasteboardFileURLs() -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        let objects = NSPasteboard.general.readObjects(forClasses: [NSURL.self], options: options)
        return (objects as? [URL]) ?? []
    }

    func paste(into destination: URL? = nil) {
        let sources = pasteboardFileURLs()
        guard !sources.isEmpty else { return }
        let target = destination ?? currentFolder
        let isMove = !cutURLs.isEmpty && NSPasteboard.general.changeCount == cutChangeCount
        var created: [String] = []

        runFileOperation({
            let fm = FileManager.default
            for source in sources {
                let sourcePath = source.standardizedFileURL.path
                if ExplorerModel.isAncestorOrSame(sourcePath, of: target.path) && sourcePath != "/" {
                    throw ExplorerError.message("“\(source.lastPathComponent)” kendi içine kopyalanamaz veya taşınamaz.")
                }
                if isMove {
                    if source.deletingLastPathComponent().path == target.path { continue }
                    let dest = ExplorerModel.uniqueURL(in: target, name: source.lastPathComponent, copySuffix: false)
                    try fm.moveItem(at: source, to: dest)
                    created.append(dest.path)
                } else {
                    let dest = ExplorerModel.uniqueURL(in: target, name: source.lastPathComponent, copySuffix: true)
                    try fm.copyItem(at: source, to: dest)
                    created.append(dest.path)
                }
            }
        }, completion: {
            if isMove {
                self.cutURLs = []
                self.cutChangeCount = -1
            }
            if target.path == self.currentFolder.path {
                self.pendingSelectPaths = Set(created)
            }
        })
    }

    // MARK: - Sürükle-bırak

    /// Bırakma anında çağrılır; işlemi yapmadan önce kullanıcıya sorar.
    func requestDrop(_ urls: [URL], into target: URL) {
        let targetPath = target.standardizedFileURL.path
        let sources = urls
            .filter { $0.isFileURL }
            .map { $0.standardizedFileURL }
            .filter { $0.path != targetPath && $0.deletingLastPathComponent().path != targetPath }
        guard !sources.isEmpty else { return }

        // Bırakma işlemi bitsin, sonra diyalog açılsın.
        DispatchQueue.main.async {
            if let bad = sources.first(where: { ExplorerModel.isAncestorOrSame($0.path, of: targetPath) }) {
                self.errorMessage = "“\(bad.lastPathComponent)” kendi içine taşınamaz veya kopyalanamaz."
                return
            }
            self.pendingDropSources = sources
            self.pendingDropTarget = target
            self.showDropConfirm = true
        }
    }

    var dropMessage: String {
        guard let target = pendingDropTarget else { return "" }
        let targetName = FileManager.default.displayName(atPath: target.path)
        if pendingDropSources.count == 1, let only = pendingDropSources.first {
            return "“\(only.lastPathComponent)” öğesini “\(targetName)” klasörüne taşımak mı, kopyalamak mı istiyorsunuz?"
        }
        return "\(pendingDropSources.count) öğeyi “\(targetName)” klasörüne taşımak mı, kopyalamak mı istiyorsunuz?"
    }

    func cancelDrop() {
        pendingDropSources = []
        pendingDropTarget = nil
    }

    func performDrop(move: Bool) {
        let sources = pendingDropSources
        guard let target = pendingDropTarget, !sources.isEmpty else { return }
        cancelDrop()
        let current = currentFolder.path
        var created: [String] = []
        var relocated: String?

        runFileOperation({
            let fm = FileManager.default
            for source in sources {
                let dest = ExplorerModel.uniqueURL(in: target, name: source.lastPathComponent, copySuffix: !move)
                if move {
                    try fm.moveItem(at: source, to: dest)
                    // Görüntülenen klasör taşındıysa yeni yerinden devam et.
                    if ExplorerModel.isAncestorOrSame(source.path, of: current) {
                        relocated = dest.path + String(current.dropFirst(source.path.count))
                    }
                } else {
                    try fm.copyItem(at: source, to: dest)
                }
                created.append(dest.path)
            }
        }, completion: {
            if let relocated {
                self.navigate(to: URL(fileURLWithPath: relocated))
            } else if target.path == self.currentFolder.path {
                self.pendingSelectPaths = Set(created)
            }
        })
    }

    // MARK: - Dosya işlemleri

    func trashSelection() { trash(Array(selection)) }

    func trash(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        runFileOperation({
            for url in urls {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            }
        })
    }

    func duplicate(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        var created: [String] = []
        runFileOperation({
            for url in urls {
                let dest = ExplorerModel.uniqueURL(in: url.deletingLastPathComponent(),
                                                   name: url.lastPathComponent, copySuffix: true)
                try FileManager.default.copyItem(at: url, to: dest)
                created.append(dest.path)
            }
        }, completion: {
            self.pendingSelectPaths = Set(created)
        })
    }

    func beginRenameSelection() {
        guard selection.count == 1, let url = selection.first else { return }
        beginRename(url)
    }

    func beginRename(_ url: URL) {
        renameURL = url
        nameInput = url.lastPathComponent
        showRename = true
    }

    func commitRename() {
        guard let source = renameURL else { return }
        renameURL = nil
        let newName = nameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty, newName != source.lastPathComponent else { return }
        guard let dest = validatedDestination(in: source.deletingLastPathComponent(), name: newName,
                                              allowCaseChangeOf: source) else { return }
        runFileOperation({
            try FileManager.default.moveItem(at: source, to: dest)
        }, completion: {
            self.pendingSelectPaths = [dest.path]
        })
    }

    func beginNewFolder() {
        nameInput = "Yeni Klasör"
        showNewFolder = true
    }

    func commitNewFolder() {
        let name = nameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let dest = validatedDestination(in: currentFolder, name: name) else { return }
        runFileOperation({
            try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: false)
        }, completion: {
            self.pendingSelectPaths = [dest.path]
        })
    }

    func beginNewFile() {
        nameInput = "Yeni Belge.txt"
        showNewFile = true
    }

    func commitNewFile() {
        let name = nameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let dest = validatedDestination(in: currentFolder, name: name) else { return }
        runFileOperation({
            if !FileManager.default.createFile(atPath: dest.path, contents: Data()) {
                throw ExplorerError.message("“\(name)” oluşturulamadı.")
            }
        }, completion: {
            self.pendingSelectPaths = [dest.path]
        })
    }

    func selectAll() {
        selection = Set(items.map { $0.id })
    }

    // MARK: - Yardımcılar

    private func validatedDestination(in folder: URL, name: String, allowCaseChangeOf source: URL? = nil) -> URL? {
        if name.contains("/") || name == "." || name == ".." {
            errorMessage = "Geçersiz ad: “\(name)”"
            return nil
        }
        let dest = folder.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: dest.path) {
            // Yalnızca büyük/küçük harf değişikliğine izin ver.
            let caseOnly = source.map { $0.lastPathComponent.lowercased() == name.lowercased() } ?? false
            if !caseOnly {
                errorMessage = "“\(name)” adında bir öğe zaten var."
                return nil
            }
        }
        return dest
    }

    private func runFileOperation(_ work: @escaping () throws -> Void, completion: (() -> Void)? = nil) {
        busy = true
        DispatchQueue.global(qos: .userInitiated).async {
            var failure: Error?
            do {
                try work()
            } catch {
                failure = error
            }
            DispatchQueue.main.async {
                self.busy = false
                if let failure {
                    self.errorMessage = failure.localizedDescription
                }
                completion?()
                self.reload()
                self.treeRevision += 1
            }
        }
    }

    static func uniqueURL(in folder: URL, name: String, copySuffix: Bool) -> URL {
        let fm = FileManager.default
        var candidate = folder.appendingPathComponent(name)
        if !fm.fileExists(atPath: candidate.path) { return candidate }

        let ext = (name as NSString).pathExtension
        let base = (name as NSString).deletingPathExtension
        var counter = 1
        repeat {
            let suffix: String
            if copySuffix {
                suffix = counter == 1 ? " kopya" : " kopya \(counter)"
            } else {
                suffix = " \(counter + 1)"
            }
            let newName = ext.isEmpty ? base + suffix : base + suffix + "." + ext
            candidate = folder.appendingPathComponent(newName)
            counter += 1
        } while fm.fileExists(atPath: candidate.path)
        return candidate
    }

    // MARK: - Klavye (Enter, Boşluk, Backspace)

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self,
                  let window = NSApp.keyWindow,
                  window.attachedSheet == nil
            else { return event }

            let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
            guard modifiers.isEmpty else { return event }

            if self.treeFocused {
                if window.firstResponder is NSTextView { return event }
                return self.handleTreeKey(event)
            }

            guard window.firstResponder is NSTableView else { return event }
            switch event.keyCode {
            case 36, 76: // Return, Enter
                if !self.selection.isEmpty {
                    self.openSelection()
                    return nil
                }
            case 49: // Boşluk
                if !self.selection.isEmpty || self.quickLookURL != nil {
                    self.toggleQuickLook()
                    return nil
                }
            case 51: // Backspace
                if self.canGoBack {
                    self.goBack()
                    return nil
                }
            default:
                break
            }
            return event
        }
    }

    /// Ağaçta Windows Explorer tuşları: ↑ ↓ gezinir, → açar / ilk alt klasöre iner,
    /// ← kapatır / üst klasöre çıkar, Enter aç-kapa yapar.
    private func handleTreeKey(_ event: NSEvent) -> NSEvent? {
        let rows = treeRows
        guard let currentID = currentTreeRowID,
              let index = rows.firstIndex(where: { $0.id == currentID })
        else { return event }
        let row = rows[index]

        switch event.keyCode {
        case 126: // ↑
            if index > 0, !rows[index - 1].isComputer { selectTreeRow(rows[index - 1]) }
            return nil
        case 125: // ↓
            if index + 1 < rows.count { selectTreeRow(rows[index + 1]) }
            return nil
        case 124: // →
            if !row.isExpanded {
                if row.hasChildren { setExpanded(row, true) }
            } else if index + 1 < rows.count, rows[index + 1].depth == row.depth + 1 {
                selectTreeRow(rows[index + 1])
            }
            return nil
        case 123: // ←
            if row.isExpanded {
                setExpanded(row, false)
            } else if row.depth > 0,
                      let parent = rows[..<index].last(where: { $0.depth == row.depth - 1 }),
                      !parent.isComputer {
                selectTreeRow(parent)
            }
            return nil
        case 36, 76: // Return, Enter
            if row.hasChildren { toggleExpanded(row) }
            return nil
        case 51: // Backspace
            if canGoBack {
                goBack()
                return nil
            }
            return event
        default:
            return event
        }
    }

    /// Tıklanan yer ağaç mı dosya listesi mi, ona göre klavye odağını belirler.
    private func installMouseMonitor() {
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self, let content = event.window?.contentView else { return event }
            var view = content.hitTest(event.locationInWindow)
            while let current = view {
                if let table = current as? NSTableView {
                    let inTree = table.numberOfColumns <= 1
                    if self.treeFocused != inTree { self.treeFocused = inTree }
                    break
                }
                view = current.superview
            }
            return event
        }
    }
}

enum ExplorerError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let text): return text
        }
    }
}
