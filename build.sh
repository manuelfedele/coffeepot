#!/usr/bin/env bash
# Build CoffeePot.app, a self-contained macOS menu-bar app, no Xcode project
# required (uses the command-line Swift toolchain only).
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="CoffeePot"
BUNDLE_ID="com.manuelfedele.coffeepot"
BUILD_DIR="build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RES_DIR="$APP_DIR/Contents/Resources"

echo "==> Cleaning"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RES_DIR"

FRAMEWORKS=(-framework AppKit -framework CoreGraphics -framework IOKit
	-framework ServiceManagement -framework ImageIO
	-framework UniformTypeIdentifiers)

echo "==> Generating app icon"
swiftc -O "${FRAMEWORKS[@]}" \
	Tools/GenerateAppIcon.swift Sources/CoffeePot/StatusIcon.swift \
	-o "$BUILD_DIR/genicon"
"$BUILD_DIR/genicon" "$BUILD_DIR/AppIcon.iconset"
iconutil -c icns "$BUILD_DIR/AppIcon.iconset" -o "$RES_DIR/AppIcon.icns"

echo "==> Compiling $APP_NAME"
# Build a universal binary (arm64 + x86_64) so it runs on any Mac.
swiftc -O \
	-target arm64-apple-macos13.0 \
	"${FRAMEWORKS[@]}" \
	Sources/CoffeePot/*.swift \
	-o "$MACOS_DIR/${APP_NAME}-arm64"
swiftc -O \
	-target x86_64-apple-macos13.0 \
	"${FRAMEWORKS[@]}" \
	Sources/CoffeePot/*.swift \
	-o "$MACOS_DIR/${APP_NAME}-x86_64"
lipo -create \
	"$MACOS_DIR/${APP_NAME}-arm64" \
	"$MACOS_DIR/${APP_NAME}-x86_64" \
	-output "$MACOS_DIR/$APP_NAME"
rm -f "$MACOS_DIR/${APP_NAME}-arm64" "$MACOS_DIR/${APP_NAME}-x86_64"

echo "==> Installing Info.plist"
cp Info.plist "$APP_DIR/Contents/Info.plist"
printf 'APPL????' >"$APP_DIR/Contents/PkgInfo"

echo "==> Code signing (ad-hoc)"
# Ad-hoc signature: required for the Hardened-Runtime-free local install and for
# SMAppService login-item registration to behave. Replace "-" with a Developer
# ID identity if you have one.
codesign --force --deep --sign - \
	--identifier "$BUNDLE_ID" \
	"$APP_DIR"

codesign --verify --verbose "$APP_DIR" || true

echo "==> Built $APP_DIR"
echo "    Run:    open \"$APP_DIR\""
echo "    Install: ./install.sh"
