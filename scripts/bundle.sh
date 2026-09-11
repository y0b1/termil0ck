#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
APP_DIR="$ROOT_DIR/Termilock.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
BUILD_CONFIGURATION="${TERMILOCK_BUILD_CONFIGURATION:-debug}"
BIN_DIR="$(cd "$ROOT_DIR" && swift build -c "$BUILD_CONFIGURATION" --show-bin-path)"
SIGNING_IDENTITY="${TERMILOCK_SIGNING_IDENTITY:-Termilock Local Development}"

if ! security find-identity -v -p codesigning | grep -Fq "\"$SIGNING_IDENTITY\""; then
    echo "Missing code-signing identity: $SIGNING_IDENTITY" >&2
    echo "Install the local Termilock identity or set TERMILOCK_SIGNING_IDENTITY." >&2
    exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
cp "$BIN_DIR/Termilock" "$MACOS_DIR/Termilock"
cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
codesign --force --deep --options runtime --timestamp=none --sign "$SIGNING_IDENTITY" "$APP_DIR"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"
echo "Built $APP_DIR (signed by $SIGNING_IDENTITY)"
