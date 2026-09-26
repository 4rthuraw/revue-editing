#!/bin/zsh
# Construit dist/Revue Montage.app (release, signée localement).
set -euo pipefail

ROOT="${0:A:h:h}"
APP="$ROOT/dist/Revue Montage.app"
cd "$ROOT"

echo "→ Vérifications de NotesCore"
swift run -c release NotesCoreChecks

echo "→ Compilation de l'app"
swift build -c release --product RevueMontage
BIN="$(swift build -c release --show-bin-path)/RevueMontage"

echo "→ Assemblage du paquet .app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/RevueMontage"

ICONSET="$ROOT/.build/AppIcon.iconset"
rm -rf "$ICONSET"
swift "$ROOT/scripts/make-icon.swift" "$ICONSET"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Revue Montage</string>
    <key>CFBundleDisplayName</key><string>Revue Montage</string>
    <key>CFBundleIdentifier</key><string>com.arthurbardin.revuemontage</string>
    <key>CFBundleExecutable</key><string>RevueMontage</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.video</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>CFBundleDevelopmentRegion</key><string>fr</string>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key><string>Vidéo</string>
            <key>CFBundleTypeRole</key><string>Viewer</string>
            <key>LSHandlerRank</key><string>Alternate</string>
            <key>LSItemContentTypes</key><array><string>public.movie</string></array>
        </dict>
    </array>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP"
echo "✓ $APP"
echo "  Pour l'installer : glisse-la dans /Applications."
