# Termilock

A compact macOS menu-bar password vault for developers. Unlock with Touch ID, find a credential, copy what you need, and get back to work.

[Install version 0.1.0](dist/Termilock-0.1.0.dmg) · [Release notes](RELEASE_NOTES.md)

## Requirements

- macOS 14 or newer.
- An Apple Silicon Mac for the included DMG.
- Touch ID configured and available. This build has no login-password fallback.

Version 0.1.0 is a local development release, signed with the existing `Termilock Local Development` identity. It is intended for the development Mac and is not notarized for public distribution.

## Install and start

1. Open [Termilock-0.1.0.dmg](dist/Termilock-0.1.0.dmg).
2. Drag **Termilock.app** onto **Applications**.
3. Open Termilock from Applications and authenticate with Touch ID.
4. Click the shield icon in the menu bar to open the vault. Termilock does not show a Dock icon.

To start Termilock when you sign in, add it under **System Settings → General → Login Items & Extensions → Open at Login**. On older macOS versions, the section is named **Login Items**. Starting at login does not bypass Touch ID.

## Use the vault

- **Add** creates a credential; existing entries can be edited or deleted.
- Search by platform or username.
- Passwords are masked until explicitly revealed. Use the copy controls to copy a value.
- **Generate** opens the password and username tools.
- The lock button saves the latest vault state and clears the unlocked vault from memory. Reopen the panel to authenticate again.
- The power button quits Termilock. Right-click or Control-click the menu-bar icon also exposes a quit command.

The Platform, User, Password, and Copy columns stay fixed while long values wrap vertically. Changes save automatically. Copied values are cleared after 30 seconds while Termilock is running, provided the clipboard still contains the value it placed there.

## Storage and security

The vault uses authenticated AES-GCM encryption and a random 256-bit key stored in the macOS login Keychain. The encrypted file lives at:

```text
~/Library/Application Support/Termilock/vault.tlvault
```

Keep the corresponding Keychain key: the vault file cannot be decrypted without it. Copying the encrypted file alone is not a complete recovery method. An unreadable or authentication-failed vault produces an error instead of being silently replaced with an empty vault.

Touch ID is currently enforced by the app before a Keychain read. The Keychain item itself does **not** yet implement the contributor guide's device-only accessibility and Keychain-enforced user-presence protection. This remains a security implementation gap in this development release.

**Security → Access & recovery** shows two incomplete capabilities:

- **Passkeys:** storage and authentication are unavailable until an AuthenticationServices credential-provider extension, entitlements, signing, and WebAuthn handling are implemented.
- **Emergency access:** trusted-contact details are stored inside the encrypted vault. No contact is notified or granted access. Requests, waiting periods, approval, and recovery are not operational.

## Build from source

Use Xcode's Swift toolchain with the macOS SDK. The package targets macOS 14 and uses SwiftUI, AppKit, CryptoKit, LocalAuthentication, and Security.

```sh
swift build
swift test
make bundle
open ./Termilock.app
```

Bundling requires the `Termilock Local Development` code-signing identity in the login Keychain. It fails if that identity is missing. To use another installed identity:

```sh
TERMILOCK_SIGNING_IDENTITY="Your signing identity" make bundle
```

Preserving the signing identity keeps the app's designated requirement stable across local rebuilds. Migrating from an older ad-hoc build may require a macOS login-Keychain authorization to retain access to the existing key.

## Build the installer

```sh
make dmg
```

This builds an optimized release app, signs and verifies it, then creates and checks a compressed DMG containing `Termilock.app`, an Applications shortcut, and installation instructions. The version comes from `Resources/Info.plist`; the current output is `dist/Termilock-0.1.0.dmg`.

Generated app bundles and Swift build output are ignored. The versioned DMG is the downloadable artifact. Public distribution still requires appropriate signing and notarization work.

## Verification status

For version 0.1.0, debug and release builds succeeded, all 9 automated tests passed, and the DMG passed checksum, mount, content, and app-signature checks on macOS 26.4.1. Termilock was confirmed running.

Interactive Touch ID and credential flows, and runtime behavior on macOS 14, still need manual verification. See the [release notes](RELEASE_NOTES.md) for the release scope.
