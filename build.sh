#!/bin/bash
# Gezgin.app üretir.
#   bash build.sh              -> debug derleme   (dist/debug/Gezgin.app)
#   bash build.sh --release    -> release derleme (dist/release/Gezgin.app)
#   bash build.sh --release --dmg  -> ayrıca dist/release/Gezgin.dmg
#   bash build.sh --run        -> derledikten sonra uygulamayı açar
#   bash build.sh --release --install  -> /Applications/Gezgin.app olarak kurar (Dock'a sabitlemek için)
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Gezgin"
BUNDLE_ID="local.gezgin.app"
VERSION="1.0"

CONFIG="debug"
MAKE_DMG=0
RUN_AFTER=0
INSTALL=0
for arg in "$@"; do
    case "$arg" in
        --release) CONFIG="release" ;;
        --debug)   CONFIG="debug" ;;
        --dmg)     MAKE_DMG=1 ;;
        --run)     RUN_AFTER=1 ;;
        --install) INSTALL=1 ;;
        *) echo "Bilinmeyen parametre: $arg"; echo "Kullanım: bash build.sh [--debug|--release] [--dmg] [--install] [--run]"; exit 1 ;;
    esac
done

echo "==> Derleniyor ($CONFIG)…"
swift build -c "$CONFIG"
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

OUT_DIR="dist/$CONFIG"
APP="$OUT_DIR/${APP_NAME}.app"
mkdir -p "$OUT_DIR"
if [ -d "$APP" ]; then mv "$APP" "$OUT_DIR/.old-$(date +%s).app"; fi
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
# Sistem menülerinin (Gizle, Çık, Pencere…) Türkçe/İngilizce görünebilmesi için
# uygulamanın desteklediği diller pakette bildirilir.
mkdir -p "$APP/Contents/Resources/tr.lproj" "$APP/Contents/Resources/en.lproj"
if [ -f "Resources/AppIcon.icns" ]; then cp "Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"; fi

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
    <key>CFBundleExecutable</key><string>${APP_NAME}</string>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleLocalizations</key><array><string>tr</string><string>en</string></array>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>NSDesktopFolderUsageDescription</key><string>Gezgin, Masaüstü klasörünüzdeki dosyaları göstermek ve yönetmek için erişim ister.</string>
    <key>NSDocumentsFolderUsageDescription</key><string>Gezgin, Belgeler klasörünüzdeki dosyaları göstermek ve yönetmek için erişim ister.</string>
    <key>NSDownloadsFolderUsageDescription</key><string>Gezgin, İndirilenler klasörünüzdeki dosyaları göstermek ve yönetmek için erişim ister.</string>
    <key>NSRemovableVolumesUsageDescription</key><string>Gezgin, harici disklerdeki dosyaları göstermek ve yönetmek için erişim ister.</string>
    <key>NSNetworkVolumesUsageDescription</key><string>Gezgin, ağ disklerindeki dosyaları göstermek ve yönetmek için erişim ister.</string>
</dict>
</plist>
EOF

echo "==> İmzalanıyor (ad-hoc)…"
codesign --force --deep --sign - "$APP"

echo "==> Hazır: $APP"

if [ "$MAKE_DMG" = "1" ]; then
    DMG="$OUT_DIR/${APP_NAME}.dmg"
    STAGE="$(mktemp -d)"
    cp -R "$APP" "$STAGE/"
    ln -s /Applications "$STAGE/Applications"
    if [ -f "$DMG" ]; then mv "$DMG" "$OUT_DIR/.old-$(date +%s).dmg"; fi
    hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
    echo "==> Hazır: $DMG"
fi

if [ "$INSTALL" = "1" ]; then
    INSTALLED="/Applications/${APP_NAME}.app"
    # Aynı paketin üzerine yazılır; böylece Dock'taki simge çalışmaya devam eder.
    ditto "$APP" "$INSTALLED"
    echo "==> Kuruldu: $INSTALLED"
    APP="$INSTALLED"
fi

if [ "$RUN_AFTER" = "1" ]; then
    open "$APP"
else
    echo "Çalıştırmak için:  open \"$APP\""
fi
