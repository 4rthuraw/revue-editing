#!/bin/zsh
# Construit l'app puis l'image disque à joindre à une Release GitHub.
# Usage : VERSION=1.0.0 ./scripts/make-dmg.sh   →   dist/RevueMontage-1.0.0.dmg
set -euo pipefail

ROOT="${0:A:h:h}"
VERSION="${VERSION:-1.0.0}"
APP="$ROOT/dist/Revue Montage.app"
DMG="$ROOT/dist/RevueMontage-$VERSION.dmg"
STAGING="$ROOT/.build/dmg"

VERSION="$VERSION" "$ROOT/scripts/build-app.sh"

echo "→ Image disque"
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
ditto "$APP" "$STAGING/Revue Montage.app"
ln -s /Applications "$STAGING/Applications"
cat > "$STAGING/LISEZ-MOI - READ ME.txt" <<'TXT'
REVUE MONTAGE — INSTALLATION

1. Glisse « Revue Montage » dans le dossier Applications.
2. Première ouverture : macOS affiche que l'app n'a pas pu être vérifiée.
   C'est normal : l'app est gratuite et n'est pas signée avec un compte développeur Apple payant.
   → Ouvre Réglages Système → Confidentialité et sécurité, descends jusqu'au message sur
     Revue Montage et clique « Ouvrir quand même », puis confirme. À faire une seule fois.
   (Ou, dans le Terminal : xattr -dr com.apple.quarantine "/Applications/Revue Montage.app")
3. Premiere Pro : dans l'app, Réglages (⌘,) → Général → Premiere Pro → Installer.

Aide et code source : https://github.com/4rthuraw/revue-editing

-----------------------------------------------------------------------------------------

REVUE MONTAGE — INSTALLATION

1. Drag "Revue Montage" into the Applications folder.
2. First launch: macOS says the app couldn't be verified.
   That's expected: the app is free and isn't signed with a paid Apple developer account.
   → Open System Settings → Privacy & Security, scroll down to the message about
     Revue Montage and click "Open Anyway", then confirm. You only need to do this once.
   (Or, in Terminal: xattr -dr com.apple.quarantine "/Applications/Revue Montage.app")
3. Premiere Pro: in the app, Settings (⌘,) → General → Premiere Pro → Install.

Help and source code: https://github.com/4rthuraw/revue-editing
TXT

hdiutil create -volname "Revue Montage $VERSION" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGING"
echo "✓ $DMG"
echo "  Architecture : $(lipo -archs "$APP/Contents/MacOS/RevueMontage")"
