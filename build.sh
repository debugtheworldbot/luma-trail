#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
STAGING=$(mktemp -d /private/tmp/luma-trail-build.XXXXXX)
APP="$STAGING/Luma Trail.app"
CACHE="$PWD/.build/swift-module-cache"
DIST="$PWD/dist"
SPARKLE=$(bash scripts/prepare-sparkle.sh)
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$CACHE" "$DIST"
mkdir -p "$APP/Contents/Frameworks"
ditto "$SPARKLE/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"
# This app is arm64-only and does not enable App Sandbox or Sparkle's XPC services.
# Trim only the fresh staging copy; keep the verified download intact.
FRAMEWORK="$APP/Contents/Frameworks/Sparkle.framework"
rm -rf "$FRAMEWORK/Versions/B/XPCServices" "$FRAMEWORK/XPCServices"
for binary in Sparkle Autoupdate Updater.app/Contents/MacOS/Updater; do
  path="$FRAMEWORK/Versions/B/$binary"
  xcrun lipo "$path" -thin arm64 -output "$path.arm64"
  mv "$path.arm64" "$path"
  [[ "$(xcrun lipo -archs "$path")" == "arm64" ]]
done
# Re-sign modified helpers from the inside out, retaining Hardened Runtime.
codesign --force --sign - --options runtime "$FRAMEWORK/Versions/B/Autoupdate"
codesign --force --sign - --options runtime "$FRAMEWORK/Versions/B/Updater.app"
codesign --force --sign - --options runtime "$FRAMEWORK"
cp "$SPARKLE/LICENSE" "$APP/Contents/Resources/Sparkle-LICENSE.txt"
xcrun clang -target arm64-apple-macosx13.0 -fobjc-arc -fmodules -fmodules-cache-path="$CACHE" -c Sources/CursorBridge.m -o "$STAGING/CursorBridge.o"
xcrun swiftc -swift-version 5 -O -module-cache-path "$CACHE" \
  -target arm64-apple-macosx13.0 -framework AppKit -framework Carbon \
  -F "$SPARKLE" -framework Sparkle -Xlinker -rpath -Xlinker @executable_path/../Frameworks \
  -import-objc-header Sources/CursorBridge.h "$STAGING/CursorBridge.o" \
  Sources/AquaStyle.swift Sources/CursorAppearance.swift Sources/FolderIcons.swift Sources/TrailNature.swift Sources/TrailGlow.swift \
  Sources/TrailFestive.swift Sources/TrailInk.swift Sources/TrailPaths.swift Sources/Particles.swift Sources/AppUpdater.swift Sources/main.swift \
  -o "$APP/Contents/MacOS/LumaTrail"
cp Info.plist "$APP/Contents/Info.plist"
if [[ -n "${BUILD_NUMBER:-}" ]]; then
  [[ "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]] || { echo "Invalid BUILD_NUMBER" >&2; exit 1; }
  plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$APP/Contents/Info.plist"
fi
cp Assets/SettingsBanner.png "$APP/Contents/Resources/SettingsBanner.png"
ICONSET="$STAGING/AppIcon.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" Assets/AppIcon.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  sips -z "$((size * 2))" "$((size * 2))" Assets/AppIcon.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
"$APP/Contents/MacOS/LumaTrail" --self-test
# ditto merges existing directories, which would otherwise retain removed XPCs.
if [[ -e "$DIST/Luma Trail.app" ]]; then
  mv "$DIST/Luma Trail.app" "$STAGING/Previous Luma Trail.app"
fi
ditto "$APP" "$DIST/Luma Trail.app"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$DIST/Luma-Trail-MVP.zip"
echo "Built: $DIST/Luma Trail.app"
echo "Signed staging bundle: $APP"
