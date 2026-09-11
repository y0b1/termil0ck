#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
APP_DIR="$ROOT_DIR/Termilock.app"
BUILD_CONFIGURATION="${TERMILOCK_BUILD_CONFIGURATION:-debug}"
SIGNING_IDENTITY="${TERMILOCK_SIGNING_IDENTITY:-}"
PROFILE="${TERMILOCK_PROVISIONING_PROFILE:-}"

if [[ -z "$SIGNING_IDENTITY" || ! -f "$PROFILE" ]]; then
    echo "Protected Keychain access requires an Apple signing identity and an authorized macOS provisioning profile." >&2
    echo "Set TERMILOCK_SIGNING_IDENTITY and TERMILOCK_PROVISIONING_PROFILE. The existing app has been preserved." >&2
    exit 1
fi
if ! security find-identity -v -p codesigning | grep -Fq "\"$SIGNING_IDENTITY\""; then
    echo "Missing code-signing identity: $SIGNING_IDENTITY" >&2
    exit 1
fi

STAGING_DIR=$(mktemp -d "${TMPDIR:-/tmp}/termilock-bundle.XXXXXX")
trap 'rm -rf "$STAGING_DIR"' EXIT
security cms -D -i "$PROFILE" > "$STAGING_DIR/profile.plist"
python3 "$ROOT_DIR/scripts/signing-entitlements.py" "$STAGING_DIR/profile.plist" \
    "$ROOT_DIR/Resources/Info.plist" "$STAGING_DIR/entitlements.plist"
BIN_DIR="$(cd "$ROOT_DIR" && swift build -c "$BUILD_CONFIGURATION" --show-bin-path)"
STAGED_APP="$STAGING_DIR/Termilock.app"
mkdir -p "$STAGED_APP/Contents/MacOS"
cp "$BIN_DIR/Termilock" "$STAGED_APP/Contents/MacOS/Termilock"
cp "$ROOT_DIR/Resources/Info.plist" "$STAGED_APP/Contents/Info.plist"
cp "$PROFILE" "$STAGED_APP/Contents/embedded.provisionprofile"
codesign --force --options runtime --timestamp=none --sign "$SIGNING_IDENTITY" \
    --entitlements "$STAGING_DIR/entitlements.plist" "$STAGED_APP"
codesign --verify --deep --strict --verbose=2 "$STAGED_APP"
# Replace the previous bundle only after signing and verification succeed.
rm -rf "$APP_DIR"
ditto "$STAGED_APP" "$APP_DIR"
echo "Built $APP_DIR (signed by $SIGNING_IDENTITY)"
