import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Xcode'dan paket olarak (.app olmadan) çalıştırıldığında da
        // Dock simgesi ve menü çubuğu görünsün.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct GezginApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = ExplorerModel()

    /// Bir metin alanı düzenleniyorsa Kes/Kopyala/Yapıştır ona gitmeli.
    private var isEditingText: Bool {
        NSApp.keyWindow?.firstResponder is NSTextView
    }

    private var renameKey: KeyEquivalent {
        KeyEquivalent(Character(UnicodeScalar(NSF2FunctionKey)!))
    }

    var body: some Scene {
        Window("Gezgin", id: "main") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 820, minHeight: 480)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Yeni Klasör") { model.beginNewFolder() }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                Button("Yeni Metin Belgesi") { model.beginNewFile() }
                    .keyboardShortcut("n", modifiers: [.command, .option])
                Divider()
                Button("Aç") { model.openSelection() }
                    .keyboardShortcut("o", modifiers: .command)
                Button("Yeniden Adlandır…") { model.beginRenameSelection() }
                    .keyboardShortcut(renameKey, modifiers: [])
                Button("Çoğalt") { model.duplicate(Array(model.selection)) }
                    .keyboardShortcut("d", modifiers: .command)
                Button("Çöp Kutusuna Taşı") { model.trashSelection() }
                    .keyboardShortcut(.delete, modifiers: .command)
                Divider()
                Button("Finder'da Göster") { model.revealInFinder(Array(model.selection)) }
                Button("Burada Terminal Aç") { model.openInTerminal(model.currentFolder) }
                    .keyboardShortcut("t", modifiers: [.command, .option])
            }

            CommandGroup(replacing: .pasteboard) {
                Button("Kes") {
                    if isEditingText {
                        NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil)
                    } else {
                        model.cutSelection()
                    }
                }
                .keyboardShortcut("x", modifiers: .command)

                Button("Kopyala") {
                    if isEditingText {
                        NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil)
                    } else {
                        model.copySelection()
                    }
                }
                .keyboardShortcut("c", modifiers: .command)

                Button("Yapıştır") {
                    if isEditingText {
                        NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil)
                    } else {
                        model.paste()
                    }
                }
                .keyboardShortcut("v", modifiers: .command)

                Button("Yolu Kopyala") { model.copyPath(Array(model.selection)) }
                    .keyboardShortcut("c", modifiers: [.command, .option])

                Divider()

                Button("Tümünü Seç") {
                    if isEditingText {
                        NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
                    } else {
                        model.selectAll()
                    }
                }
                .keyboardShortcut("a", modifiers: .command)
            }

            CommandMenu("Git") {
                Button("Geri") { model.goBack() }
                    .keyboardShortcut("[", modifiers: .command)
                    .disabled(!model.canGoBack)
                Button("İleri") { model.goForward() }
                    .keyboardShortcut("]", modifiers: .command)
                    .disabled(!model.canGoForward)
                Button("Üst Klasör") { model.goUp() }
                    .keyboardShortcut(.upArrow, modifiers: .command)
                    .disabled(!model.canGoUp)
                Button("Seçileni Aç") { model.openSelection() }
                    .keyboardShortcut(.downArrow, modifiers: .command)
                Divider()
                Button("Klasöre Git…") { model.beginGoTo() }
                    .keyboardShortcut("g", modifiers: [.command, .shift])
                Button("Yenile") { model.reload() }
                    .keyboardShortcut("r", modifiers: .command)
            }

            // Görünüm menüsü
            CommandGroup(before: .toolbar) {
                Toggle("Tam Yolu Göster", isOn: $model.showFullPath)
                    .keyboardShortcut("p", modifiers: [.command, .option])
                Toggle("Gezgin İkonları", isOn: $model.useThemeIcons)
                    .keyboardShortcut("i", modifiers: [.command, .option])
                Toggle("Gizli Dosyaları Göster", isOn: $model.showHidden)
                    .keyboardShortcut(".", modifiers: [.command, .shift])
                Divider()
            }
        }
    }
}
