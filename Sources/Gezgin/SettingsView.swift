import SwiftUI

/// Ayarlar penceresi (uygulama menüsü → Ayarlar…, ⌘,).
struct SettingsView: View {
    @EnvironmentObject var model: ExplorerModel

    var body: some View {
        Form {
            Section(L("Genel")) {
                Picker(L("Dil"), selection: $model.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.title).tag(language)
                    }
                }
                Text(L("Sistem menülerinin dili, uygulama yeniden açıldığında değişir."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section(L("Görünüm")) {
                Toggle(L("Tam Yolu Göster"), isOn: $model.showFullPath)
                Toggle(L("Gezgin İkonları"), isOn: $model.useThemeIcons)
                Toggle(L("Gizli Dosyaları Göster"), isOn: $model.showHidden)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
    }
}
