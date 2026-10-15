#!/bin/bash
# Builds a universal "Ezan Pro.app" (Apple Silicon + Intel) and a zip for releases.
#   ./build.sh            build only
#   ./build.sh --install  also copy to /Applications and start
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release --arch arm64 --arch x86_64
APP="build/Ezan Pro.app"
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/apple/Products/Release/EzanPro "$APP/Contents/MacOS/EzanPro"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
(cd build && ditto -c -k --keepParent "Ezan Pro.app" EzanPro.zip)
echo "Gebaut: $APP (+ build/EzanPro.zip)"

if [[ "${1:-}" == "--install" ]]; then
    pkill -x EzanPro || true
    rm -rf "/Applications/Ezan Pro.app"
    cp -R "$APP" /Applications/
    open "/Applications/Ezan Pro.app"
    echo "Installiert und gestartet: /Applications/Ezan Pro.app"
fi
