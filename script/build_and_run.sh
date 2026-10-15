#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
MODE="${1:-run}"
if [[ "$MODE" != "--build" ]]; then pkill -x MacBlox >/dev/null 2>&1 || true; fi
swift build
BINARY="$(swift build --show-bin-path)/MacBlox"
STAGE="$(mktemp -d /private/tmp/macblox-build.XXXXXX)"
APP="$STAGE/MacBlox.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Resources/MacBlox.icns "$APP/Contents/Resources/MacBlox.icns"
cp "$BINARY" "$APP/Contents/MacOS/MacBlox"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>MacBlox</string>
<key>CFBundleIdentifier</key><string>local.macblox.manager</string>
<key>CFBundleIconFile</key><string>MacBlox</string>
<key>CFBundleName</key><string>MacBlox</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.1.1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSCameraUsageDescription</key><string>Roblox login may request camera access for verification.</string>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
mkdir -p "$PWD/dist"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$PWD/dist/MacBlox-v1.1.1-macOS-AppleSilicon.zip"
ditto "$APP" "$PWD/dist/MacBlox.app"
case "$MODE" in
  --build) ;;
  run) open -n "$APP" ;;
  --verify) open -n "$APP"; sleep 2; pgrep -x MacBlox >/dev/null ;;
  --debug) lldb -- "$APP/Contents/MacOS/MacBlox" ;;
  --logs|--telemetry) open -n "$APP"; /usr/bin/log stream --info --style compact --predicate 'process == "MacBlox"' ;;
  *) echo "Usage: $0 [--build|--verify|--debug|--logs|--telemetry]"; exit 2 ;;
esac
