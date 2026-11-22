import Foundation

/// Arayüz dili seçeneği.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case tr
    case en

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return L("Sistem dili")
        case .tr: return "Türkçe"
        case .en: return "English"
        }
    }

    static var saved: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: "language") ?? "") ?? .system
    }
}

/// Çeviri altyapısı. Kaynak metinler Türkçedir; anahtar olarak Türkçe metnin kendisi kullanılır.
/// Yeni dil eklemek için `translations` içine o dilin sözlüğünü ve `AppLanguage` içine bir seçenek eklemek yeterli.
enum Loc {
    /// Etkin dil kodu ("tr", "en"…).
    static var language = "tr"

    static let supported = ["tr", "en"]

    static func apply(_ setting: AppLanguage) {
        switch setting {
        case .system:
            // Uygulamaya özel dil tercihini kaldır, macOS'in dil sırasına bak.
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
            let global = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)
            let preferred = (global?["AppleLanguages"] as? [String]) ?? Locale.preferredLanguages
            language = "en"
            for candidate in preferred {
                let code = String(candidate.prefix(2)).lowercased()
                if supported.contains(code) {
                    language = code
                    break
                }
            }
        case .tr, .en:
            language = setting.rawValue
            // Sistem menüleri (Gizle, Çık, Pencere…) de bir sonraki açılışta bu dile geçer.
            UserDefaults.standard.set([setting.rawValue], forKey: "AppleLanguages")
        }
    }

    static func lookup(_ key: String) -> String {
        if language == "tr" { return key }
        return translations[language]?[key] ?? key
    }

    static let translations: [String: [String: String]] = [
        "en": [
            // Ağaç
            "Bu Mac": "This Mac",
            "Çıkar": "Eject",
            "Daralt": "Collapse",
            "Genişlet": "Expand",
            // Ortak komutlar
            "Aç": "Open",
            "Birlikte Aç": "Open With",
            "Buraya Yapıştır": "Paste Here",
            "İçine Yapıştır": "Paste Into",
            "Yolu Kopyala": "Copy Path",
            "Finder'da Göster": "Show in Finder",
            "Burada Terminal Aç": "Open Terminal Here",
            "Yeni Klasör": "New Folder",
            "Yeni klasör": "New folder",
            "Yeni Metin Belgesi": "New Text Document",
            "Yeni Belge": "New Document",
            "Yeniden Adlandır…": "Rename…",
            "Yeniden Adlandır": "Rename",
            "Çoğalt": "Duplicate",
            "Çöp Kutusuna Taşı": "Move to Trash",
            "Çöp Kutusuna taşı": "Move to Trash",
            "Sil": "Delete",
            "Kes": "Cut",
            "Kopyala": "Copy",
            "Yapıştır": "Paste",
            "Tümünü Seç": "Select All",
            // Gezinme
            "Git": "Go",
            "Geri": "Back",
            "İleri": "Forward",
            "Yukarı": "Up",
            "Üst Klasör": "Enclosing Folder",
            "Üst klasör": "Enclosing folder",
            "Seçileni Aç": "Open Selection",
            "Klasöre Git…": "Go to Folder…",
            "Klasöre Git": "Go to Folder",
            "Yenile": "Refresh",
            "Yol": "Path",
            // Görünüm
            "Tam Yolu Göster": "Show Full Path",
            "Gezgin İkonları": "Gezgin Icons",
            "Gizli Dosyaları Göster": "Show Hidden Files",
            "Gizli Dosyalar": "Hidden Files",
            "Gizli dosyaları göster": "Show hidden files",
            "Terminal": "Terminal",
            "Bu klasörde Terminal aç": "Open Terminal in this folder",
            "Bu klasörde ara": "Search this folder",
            // Liste
            "Ad": "Name",
            "Değiştirilme": "Date Modified",
            "Boyut": "Size",
            "Tür": "Kind",
            "Eşleşen öğe yok": "No matching items",
            "Bu klasör boş": "This folder is empty",
            "%ld öğe": "%ld items",
            "%ld seçili": "%ld selected",
            "boş": "free",
            "kopya": "copy",
            // Diyaloglar
            "Vazgeç": "Cancel",
            "Tamam": "OK",
            "Oluştur": "Create",
            "Klasör adı": "Folder name",
            "Dosya adı": "File name",
            "Taşı veya Kopyala": "Move or Copy",
            "Taşı": "Move",
            "Hata": "Error",
            "“%@” öğesini “%@” klasörüne taşımak mı, kopyalamak mı istiyorsunuz?":
                "Do you want to move or copy “%@” to “%@”?",
            "%ld öğeyi “%@” klasörüne taşımak mı, kopyalamak mı istiyorsunuz?":
                "Do you want to move or copy %ld items to “%@”?",
            // Hatalar
            "“%@” çıkarılamadı.": "“%@” could not be ejected.",
            "Böyle bir konum yok:": "No such location:",
            "“%@” açılamadı.": "“%@” could not be opened.",
            "“%@” kendi içine taşınamaz veya kopyalanamaz.": "“%@” cannot be moved or copied into itself.",
            "“%@” oluşturulamadı.": "“%@” could not be created.",
            "Geçersiz ad: “%@”": "Invalid name: “%@”",
            "“%@” adında bir öğe zaten var.": "An item named “%@” already exists.",
            // Ayarlar
            "Sistem dili": "System language",
            "Dil": "Language",
            "Genel": "General",
            "Görünüm": "Appearance",
            "Sistem menülerinin dili, uygulama yeniden açıldığında değişir.":
                "System menus switch language the next time the app is opened."
        ]
    ]
}

/// Metni etkin dile çevirir. Biçim parametreleri verilirse yerine koyar.
func L(_ key: String, _ args: CVarArg...) -> String {
    let text = Loc.lookup(key)
    if args.isEmpty { return text }
    return String(format: text, arguments: args)
}
