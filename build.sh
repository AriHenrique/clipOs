#!/bin/bash
# Compila e monta Clip.app (assinatura ad-hoc). Uso: ./build.sh [--install]
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release
APP=build/Clip.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/Clip "$APP/Contents/MacOS/Clip"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Clip</string>
<key>CFBundleIdentifier</key><string>dev.aristides.clip</string>
<key>CFBundleName</key><string>Clip</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
if [[ "${1:-}" == "--install" ]]; then
  mkdir -p ~/Applications
  rm -rf ~/Applications/Clip.app
  cp -R "$APP" ~/Applications/Clip.app
  echo "Instalado em ~/Applications/Clip.app"
fi
