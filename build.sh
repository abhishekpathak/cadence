#!/bin/bash
# Builds Pomo.app (no Xcode required). Usage: ./build.sh [install]
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release
APP=Pomo.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$(swift build -c release --show-bin-path)/Pomo" "$APP/Contents/MacOS/Pomo"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Pomo</string>
<key>CFBundleIdentifier</key><string>local.abhishek.pomo</string>
<key>CFBundleExecutable</key><string>Pomo</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>0.1</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
</dict></plist>
PLIST
codesign --force -s - "$APP"
if [ "${1:-}" = "install" ]; then rm -rf /Applications/Pomo.app; cp -R "$APP" /Applications/; echo "Installed to /Applications"; fi
echo "Built $APP"
