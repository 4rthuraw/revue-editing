#!/bin/zsh
# Emballe le panneau en .ccx et l'installe dans Premiere Pro via l'installateur Adobe (UPIA).
set -euo pipefail

DIR="${0:A:h}"
OUT="$DIR/dist/ImporterLesNotes.ccx"
UPIA="/Library/Application Support/Adobe/Adobe Desktop Common/RemoteComponents/UPI/UnifiedPluginInstallerAgent/UnifiedPluginInstallerAgent.app/Contents/MacOS/UnifiedPluginInstallerAgent"

mkdir -p "$DIR/dist"
rm -f "$OUT"
(cd "$DIR/plugin" && zip -qr -X "$OUT" . -x ".*")
echo "→ Paquet : $OUT"

if [[ ! -x "$UPIA" ]]; then
  echo "✗ Installateur Adobe introuvable. Double-clique sur le .ccx, ou charge le dossier plugin/ avec UXP Developer Tool."
  exit 1
fi

"$UPIA" --install "$OUT"
echo "✓ Installé. Redémarre Premiere Pro, puis : Fenêtre → Extensions (UXP) → Importer les notes."
