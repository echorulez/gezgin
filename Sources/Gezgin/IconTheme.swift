import AppKit
import SwiftUI

/// Gezgin'e özgü ikon: bir SF Symbol ve bir renk.
/// Klasörlerde `symbol`, klasörün üstüne beyaz rozet olarak çizilir.
struct IconSpec {
    let symbol: String?
    let color: Color
}

/// Klasör adına ve dosya uzantısına göre ikon seçer.
/// Yeni tür eklemek için aşağıdaki listelere bir satır eklemek yeterli.
enum IconTheme {

    // MARK: Klasörler (ada göre, küçük harf)

    private static let folderGroups: [([String], IconSpec)] = [
        ([".git", ".github", ".gitlab"], IconSpec(symbol: "arrow.triangle.branch", color: .orange)),
        (["src", "source", "sources", "app", "lib", "libs"], IconSpec(symbol: "chevron.left.forwardslash.chevron.right", color: .green)),
        (["node_modules", "packages", "vendor", "pods", ".swiftpm", ".pub-cache", ".npm", ".nuget", ".gem"], IconSpec(symbol: "shippingbox.fill", color: .brown)),
        (["build", ".build", "dist", "out", "target", "bin", "obj", "deriveddata"], IconSpec(symbol: "hammer.fill", color: .gray)),
        (["test", "tests", "__tests__", "spec", "specs"], IconSpec(symbol: "checkmark", color: .teal)),
        (["docs", "doc", "documentation", "wiki"], IconSpec(symbol: "book.closed.fill", color: .indigo)),
        (["assets", "images", "img", "icons", "resources", "pictures", "photos", "media"], IconSpec(symbol: "photo.fill", color: .purple)),
        (["desktop"], IconSpec(symbol: "desktopcomputer", color: .blue)),
        (["documents"], IconSpec(symbol: "doc.fill", color: .blue)),
        (["downloads"], IconSpec(symbol: "arrow.down", color: .blue)),
        (["music", "audio", "sounds"], IconSpec(symbol: "music.note", color: .pink)),
        (["movies", "videos", "video"], IconSpec(symbol: "film.fill", color: .red)),
        (["applications"], IconSpec(symbol: "square.grid.2x2.fill", color: .cyan)),
        (["projects", "project", "work", "workspace", "repos", "code", "dev"], IconSpec(symbol: "cube.fill", color: .indigo)),
        (["library", "system"], IconSpec(symbol: "gearshape.2.fill", color: .gray)),
        (["config", ".config", "settings", ".vscode", ".idea", "preferences"], IconSpec(symbol: "gearshape.fill", color: .gray)),
        (["scripts", "script", "tools"], IconSpec(symbol: "terminal.fill", color: .mint)),
        ([".ssh", "keys", "certs", "certificates", "secrets"], IconSpec(symbol: "key.fill", color: .yellow)),
        ([".trash", "trash"], IconSpec(symbol: "trash.fill", color: .gray)),
        (["users"], IconSpec(symbol: "person.2.fill", color: .blue)),
        (["public", "www", "web", "site"], IconSpec(symbol: "globe", color: .cyan)),
        (["volumes"], IconSpec(symbol: "externaldrive.fill", color: .gray)),
        (["temp", "tmp", "cache", ".cache", "caches", "logs", "log"], IconSpec(symbol: "clock.fill", color: .gray)),
        (["backup", "backups", "archive", "archives"], IconSpec(symbol: "clock.arrow.circlepath", color: .brown)),
        (["fonts"], IconSpec(symbol: "textformat", color: .purple)),
        (["data", "database", "db"], IconSpec(symbol: "cylinder.fill", color: .teal))
    ]

    // MARK: Dosyalar (uzantıya göre, küçük harf)

    private static let fileGroups: [([String], IconSpec)] = [
        (["swift"], IconSpec(symbol: "swift", color: .orange)),
        (["js", "mjs", "cjs", "jsx"], IconSpec(symbol: "curlybraces.square.fill", color: .yellow)),
        (["ts", "tsx"], IconSpec(symbol: "curlybraces.square.fill", color: .blue)),
        (["py", "rb", "php", "pl", "lua", "r"], IconSpec(symbol: "chevron.left.forwardslash.chevron.right", color: .teal)),
        (["c", "h", "cpp", "hpp", "cc", "m", "mm", "cs", "java", "kt", "go", "rs", "dart"], IconSpec(symbol: "chevron.left.forwardslash.chevron.right", color: .indigo)),
        (["html", "htm", "xhtml", "vue", "svelte"], IconSpec(symbol: "globe", color: .orange)),
        (["css", "scss", "sass", "less"], IconSpec(symbol: "paintbrush.fill", color: .blue)),
        (["json", "jsonc", "json5"], IconSpec(symbol: "curlybraces", color: .yellow)),
        (["xml", "plist", "yaml", "yml", "toml", "ini", "conf", "cfg", "env", "properties", "entitlements"], IconSpec(symbol: "gearshape.fill", color: .gray)),
        (["sh", "bash", "zsh", "fish", "command", "bat", "ps1"], IconSpec(symbol: "terminal.fill", color: .mint)),
        (["md", "markdown", "rst"], IconSpec(symbol: "text.alignleft", color: .blue)),
        (["txt", "text", "log", "rtf"], IconSpec(symbol: "doc.plaintext.fill", color: .gray)),
        (["pdf"], IconSpec(symbol: "doc.richtext.fill", color: .red)),
        (["doc", "docx", "pages", "odt"], IconSpec(symbol: "doc.text.fill", color: .blue)),
        (["xls", "xlsx", "numbers", "csv", "tsv", "ods"], IconSpec(symbol: "tablecells.fill", color: .green)),
        (["ppt", "pptx", "key", "odp"], IconSpec(symbol: "play.rectangle.fill", color: .orange)),
        (["png", "jpg", "jpeg", "gif", "heic", "webp", "tiff", "tif", "bmp", "ico", "icns", "raw"], IconSpec(symbol: "photo.fill", color: .purple)),
        (["svg", "ai", "eps", "psd", "sketch", "fig", "xd"], IconSpec(symbol: "paintpalette.fill", color: .pink)),
        (["mp4", "mov", "m4v", "avi", "mkv", "webm", "wmv"], IconSpec(symbol: "film.fill", color: .red)),
        (["mp3", "wav", "aac", "m4a", "flac", "ogg", "aiff"], IconSpec(symbol: "music.note", color: .pink)),
        (["zip", "tar", "gz", "tgz", "bz2", "xz", "7z", "rar"], IconSpec(symbol: "doc.zipper", color: .brown)),
        (["dmg", "iso", "img", "pkg"], IconSpec(symbol: "externaldrive.fill", color: .gray)),
        (["sql", "db", "sqlite", "sqlite3", "realm"], IconSpec(symbol: "cylinder.fill", color: .teal)),
        (["ttf", "otf", "woff", "woff2"], IconSpec(symbol: "textformat", color: .purple)),
        (["pem", "crt", "cer", "p12", "pub", "gpg", "asc"], IconSpec(symbol: "key.fill", color: .yellow)),
        (["lock"], IconSpec(symbol: "lock.fill", color: .gray)),
        (["epub", "mobi"], IconSpec(symbol: "book.closed.fill", color: .indigo)),
        (["ipynb"], IconSpec(symbol: "chart.bar.doc.horizontal.fill", color: .orange))
    ]

    // MARK: Dosyalar (tam ada göre, küçük harf)

    private static let fileNameGroups: [([String], IconSpec)] = [
        ([".gitignore", ".gitattributes", ".gitmodules", ".gitkeep"], IconSpec(symbol: "arrow.triangle.branch", color: .orange)),
        (["dockerfile", "docker-compose.yml", "docker-compose.yaml", ".dockerignore"], IconSpec(symbol: "shippingbox.fill", color: .blue)),
        (["makefile", "rakefile", "gemfile", "podfile", "cmakelists.txt"], IconSpec(symbol: "hammer.fill", color: .gray)),
        (["license", "license.md", "license.txt", "copying"], IconSpec(symbol: "checkmark.seal.fill", color: .green)),
        (["readme", "readme.md", "readme.txt"], IconSpec(symbol: "book.closed.fill", color: .blue)),
        ([".ds_store", ".localized"], IconSpec(symbol: "gearshape.fill", color: .gray)),
        ([".env", ".env.local", ".env.production", ".env.development"], IconSpec(symbol: "key.fill", color: .yellow))
    ]

    private static func table(_ groups: [([String], IconSpec)]) -> [String: IconSpec] {
        var result: [String: IconSpec] = [:]
        for (names, spec) in groups {
            for name in names {
                result[name] = spec
            }
        }
        return result
    }

    private static let folders = table(folderGroups)
    private static let extensions = table(fileGroups)
    private static let fileNames = table(fileNameGroups)

    /// Temada karşılığı yoksa nil döner; o durumda sistem ikonu kullanılır.
    static func spec(name: String, isDirectory: Bool, isPackage: Bool) -> IconSpec? {
        // Uygulamalar ve paketler kendi gerçek ikonlarıyla kalsın.
        if isPackage { return nil }
        let lower = name.lowercased()

        if isDirectory {
            if let known = folders[lower] { return known }
            // Bilinmeyen klasör: gizliyse gri, değilse mavi düz klasör.
            return IconSpec(symbol: nil, color: lower.hasPrefix(".") ? .gray : .blue)
        }

        if let known = fileNames[lower] { return known }
        let ext = (lower as NSString).pathExtension
        if !ext.isEmpty, let known = extensions[ext] { return known }
        return nil
    }
}

/// Bir dosya veya klasörün ikonu: tema açıksa Gezgin ikonu, değilse sistem ikonu.
struct ItemIcon: View {
    /// Tema açık mı (model.useThemeIcons).
    let themed: Bool
    let url: URL
    let name: String
    let isDirectory: Bool
    let isPackage: Bool
    let size: CGFloat

    var body: some View {
        if themed,
           let spec = IconTheme.spec(name: name, isDirectory: isDirectory, isPackage: isPackage) {
            themed(spec)
        } else {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        }
    }

    @ViewBuilder
    private func themed(_ spec: IconSpec) -> some View {
        if isDirectory {
            ZStack {
                Image(systemName: "folder.fill")
                    .font(.system(size: size * 0.9))
                    .foregroundStyle(spec.color)
                if let badge = spec.symbol {
                    Image(systemName: badge)
                        .font(.system(size: size * 0.38, weight: .bold))
                        .foregroundStyle(.white)
                        .offset(y: size * 0.07)
                }
            }
            .frame(width: size, height: size)
        } else {
            Image(systemName: spec.symbol ?? "doc.fill")
                .font(.system(size: size * 0.82))
                .foregroundStyle(spec.color)
                .frame(width: size, height: size)
        }
    }
}
