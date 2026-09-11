#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
STAGING=$(mktemp -d /private/tmp/luma-trail-build.XXXXXX)
APP="$STAGING/Luma Trail.app"
CACHE="$PWD/.build/swift-module-cache"
DIST="$PWD/dist"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$CACHE" "$DIST"
xcrun clang -target arm64-apple-macosx13.0 -fobjc-arc -fmodules -fmodules-cache-path="$CACHE" -c Sources/CursorBridge.m -o "$STAGING/CursorBridge.o"
xcrun swiftc -swift-version 5 -O -module-cache-path "$CACHE" \
  -target arm64-apple-macosx13.0 -framework AppKit -framework Carbon \
  -import-objc-header Sources/CursorBridge.h "$STAGING/CursorBridge.o" Sources/CursorAppearance.swift Sources/Particles.swift Sources/main.swift -o "$APP/Contents/MacOS/LumaTrail"
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
"$APP/Contents/MacOS/LumaTrail" --self-test
ditto "$APP" "$DIST/Luma Trail.app"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$DIST/Luma-Trail-MVP.zip"
echo "Built: $DIST/Luma Trail.app"
echo "Signed staging bundle: $APP"
