import AppKit

/// Sağ paneldeki tek bir satır (dosya veya klasör).
struct FileItem: Identifiable, Hashable {
    let url: URL
    let name: String
    /// İçine girilebilen klasör (uygulama paketleri hariç).
    let isDirectory: Bool
    let isPackage: Bool
    let isHidden: Bool
    let size: Int64
    let modified: Date
    let kind: String

    var id: URL { url }

    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }

    var sizeText: String {
        if isDirectory || isPackage { return "—" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    static let resourceKeys: [URLResourceKey] = [
        .isDirectoryKey, .isPackageKey, .isHiddenKey, .isSymbolicLinkKey,
        .fileSizeKey, .contentModificationDateKey, .localizedTypeDescriptionKey
    ]

    init(url: URL) {
        let values = try? url.resourceValues(forKeys: Set(FileItem.resourceKeys))
        var isDir = values?.isDirectory ?? false
        if values?.isSymbolicLink == true {
            let resolved = url.resolvingSymlinksInPath()
            let resolvedValues = try? resolved.resourceValues(forKeys: [.isDirectoryKey])
            isDir = resolvedValues?.isDirectory ?? false
        }
        let package = values?.isPackage ?? false

        self.url = url
        self.name = url.lastPathComponent
        self.isPackage = package
        self.isDirectory = isDir && !package
        self.isHidden = values?.isHidden ?? false
        self.size = Int64(values?.fileSize ?? 0)
        self.modified = values?.contentModificationDate ?? Date.distantPast
        self.kind = values?.localizedTypeDescription ?? ""
    }
}

struct PathCrumb {
    /// Görünen ad (ör. "Macintosh HD", "Belgeler").
    let title: String
    let url: URL
    /// Gerçek yol parçası (ör. "/", "Documents").
    let component: String
}

struct Favorite: Identifiable {
    let title: String
    let systemImage: String
    let url: URL
    var id: String { url.path }
}

/// Soldaki ağaçta görünen tek bir satır.
struct TreeRow: Identifiable {
    let id: String
    let url: URL
    let rootPath: String
    let depth: Int
    let isExpanded: Bool
    /// Alt klasörler henüz okunmadıysa true kabul edilir.
    let hasChildren: Bool
    /// Çıkarılabilen bağlı disk (DMG, USB…).
    let isVolume: Bool
    /// En üstteki sanal "Bu Mac" düğümü (gerçek bir klasör değildir).
    var isComputer = false
}
