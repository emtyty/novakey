#!/bin/bash
set -e
cd "$(dirname "$0")"

APP="build/NovaKey.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "▶ Building..."
swift build -c release

echo "▶ Assembling app bundle..."
mkdir -p "$MACOS" "$RESOURCES"

# Binary
cp .build/release/NovaKey "$MACOS/NovaKey"
chmod +x "$MACOS/NovaKey"

# All resources
cp Resources/Info.plist     "$CONTENTS/Info.plist"
cp Resources/AppIcon.icns   "$RESOURCES/AppIcon.icns"
cp Resources/AppLogo.png    "$RESOURCES/AppLogo.png"
cp Resources/NovaKey.entitlements "$RESOURCES/NovaKey.entitlements"

echo "▶ Signing (ad-hoc)..."
codesign --force --deep --sign - \
    --entitlements Resources/NovaKey.entitlements \
    --options runtime \
    "$APP"

echo "▶ Verifying bundle..."
codesign --verify --deep --strict "$APP" && echo "  Signature OK"
echo "  Bundle ID: $(defaults read "$(pwd)/$CONTENTS/Info" CFBundleIdentifier)"
echo "  Version:   $(defaults read "$(pwd)/$CONTENTS/Info" CFBundleShortVersionString)"

echo "✓ Done: $APP"
