#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
APP_DIR="$ROOT_DIR/Termilock.app"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_DIR/Contents/Info.plist")
DIST_DIR="$ROOT_DIR/dist"
STAGING_DIR=$(mktemp -d "${TMPDIR:-/tmp}/termilock-dmg.XXXXXX")
trap 'rm -rf "$STAGING_DIR"' EXIT

codesign --verify --deep --strict "$APP_DIR"
mkdir -p "$DIST_DIR" "$STAGING_DIR/content"
ditto "$APP_DIR" "$STAGING_DIR/content/Termilock.app"
ln -s /Applications "$STAGING_DIR/content/Applications"
cat > "$STAGING_DIR/content/Install.txt" <<'EOF'
Drag Termilock.app to Applications, then open Termilock from Applications.
Termilock appears in the macOS menu bar. Use Touch ID to unlock your vault.
Requires macOS 14 or newer and Touch ID.

To open automatically when you sign in, add Termilock in System Settings >
General > Login Items & Extensions > Open at Login.

This build uses a local development signing identity and is not notarized.
It is intended for use on the development Mac.
EOF
hdiutil create -volname "Termilock $VERSION" -srcfolder "$STAGING_DIR/content" \
    -format UDZO -ov "$STAGING_DIR/Termilock-$VERSION.dmg"
hdiutil verify "$STAGING_DIR/Termilock-$VERSION.dmg"
mv -f "$STAGING_DIR/Termilock-$VERSION.dmg" "$DIST_DIR/Termilock-$VERSION.dmg"
echo "Built $DIST_DIR/Termilock-$VERSION.dmg"
