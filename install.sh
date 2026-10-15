#!/bin/bash
# Installs the latest Ezan Pro release into /Applications.
#   curl -fsSL https://raw.githubusercontent.com/Emin-Kaya/ezan-pro/main/install.sh | bash
set -euo pipefail

URL="https://github.com/Emin-Kaya/ezan-pro/releases/latest/download/EzanPro.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Lade Ezan Pro herunter …"
curl -fsSL "$URL" -o "$TMP/EzanPro.zip"
ditto -x -k "$TMP/EzanPro.zip" "$TMP"

pkill -x EzanPro 2>/dev/null || true
rm -rf "/Applications/Ezan Pro.app"
cp -R "$TMP/Ezan Pro.app" /Applications/
# The app is not notarized by Apple; remove the download quarantine so it can open.
xattr -dr com.apple.quarantine "/Applications/Ezan Pro.app" 2>/dev/null || true

open "/Applications/Ezan Pro.app"
echo "✅ Ezan Pro ist installiert und läuft – schau oben rechts in die Menüleiste."
