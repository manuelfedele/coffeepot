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

echo "==> Generating app icon (from Resources/moka.svg)"
swiftc -O -parse-as-library "${FRAMEWORKS[@]}" \
	Tools/GenerateAppIcon.swift \
	-o "$BUILD_DIR/genicon"
"$BUILD_DIR/genicon" Resources/moka.svg "$BUILD_DIR/AppIcon.iconset"
iconutil -c icns "$BUILD_DIR/AppIcon.iconset" -o "$RES_DIR/AppIcon.icns"

echo "==> Bundling resources"
# The menu-bar icon is loaded at runtime from this SVG; it must be inside the
# bundle before code signing seals the package.
cp Resources/moka.svg "$RES_DIR/moka.svg"

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
# ID identity if you have one. (No --deep: it is deprecated for signing and the
# bundle has no nested code to sign.)
codesign --force --sign - \
	--identifier "$BUNDLE_ID" \
	"$APP_DIR"

# The signature is load-bearing for SMAppService.register(); fail loudly if it
# does not verify rather than shipping a broken bundle.
codesign --verify --verbose "$APP_DIR"

echo "==> Built $APP_DIR"
echo "    Run:    open \"$APP_DIR\""
echo "    Install: ./install.sh"
