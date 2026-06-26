#!/usr/bin/env bash
# Build (if needed) and install CoffeePot.app into /Applications, then launch it.
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="CoffeePot"
APP_DIR="build/$APP_NAME.app"
DEST="/Applications/$APP_NAME.app"

if [[ ! -d "$APP_DIR" ]]; then
	echo "==> No build found, building first"
	./build.sh
fi

echo "==> Quitting any running instance"
osascript -e 'tell application "CoffeePot" to quit' 2>/dev/null || true
pkill -x "$APP_NAME" 2>/dev/null || true
sleep 1

echo "==> Installing to $DEST"
rm -rf "$DEST"
cp -R "$APP_DIR" "$DEST"

# Strip the quarantine attribute so Gatekeeper doesn't nag on an ad-hoc build.
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

echo "==> Launching"
open "$DEST"

echo "==> Installed. Look for the coffee pot in your menu bar."
