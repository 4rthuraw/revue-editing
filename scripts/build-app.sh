#!/bin/zsh
# Construit dist/Revue Montage.app (release, signée localement).
# Usage : ./scripts/build-app.sh            (version par défaut)
#         VERSION=1.2.0 ./scripts/build-app.sh
set -euo pipefail

ROOT="${0:A:h:h}"
APP="$ROOT/dist/Revue Montage.app"
VERSION="${VERSION:-1.0.0}"
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

echo "→ Panneau Premiere embarqué (installé depuis les Réglages de l'app)"
(cd "$ROOT/premiere-panel/plugin" && zip -qr -X "$APP/Contents/Resources/ImporterLesNotes.ccx" . -x ".*")
# Copie du manifeste : l'app y lit l'identifiant et la version pour vérifier l'installation.
cp "$ROOT/premiere-panel/plugin/manifest.json" "$APP/Contents/Resources/PremierePanel-manifest.json"

cat > "$APP/Contents/Info.plist" <<PLIST
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
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.video</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>CFBundleDevelopmentRegion</key><string>fr</string>
    <key>CFBundleLocalizations</key><array><string>fr</string><string>en</string></array>
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
echo "✓ $APP (version $VERSION)"
echo "  Pour l'installer : glisse-la dans /Applications."
