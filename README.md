# Termilock

A compact macOS menu-bar password vault for developers. Unlock with Touch ID, find a credential, copy what you need, and get back to work.

[Release notes](RELEASE_NOTES.md)

**Source version 0.1.1 is awaiting provisioning and real-device verification.** It implements protected Keychain storage, but no 0.1.1 installer has been built. The retained [0.1.0 DMG](dist/Termilock-0.1.0.dmg) predates this fix and still uses app-level authentication.

## Requirements

- macOS 14 or newer.
- An Apple Silicon Mac for the included DMG.
- Touch ID configured and available. This build has no login-password fallback.

Version 0.1.0 is a local development release, signed with the existing `Termilock Local Development` identity. It is intended for the development Mac and is not notarized for public distribution.

## Install and start (existing 0.1.0 installer)

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

The vault uses authenticated AES-GCM encryption and a random 256-bit key. Version 0.1.1 source stores the key in the macOS Data Protection Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, synchronization disabled, and a `.biometryAny` access-control constraint. macOS enforces biometric authentication on protected key reads. The encrypted file lives at:

```text
~/Library/Application Support/Termilock/vault.tlvault
```

Keep the corresponding Keychain key: the vault file cannot be decrypted without it. Copying the encrypted file alone is not a complete recovery method. An unreadable or authentication-failed vault produces an error instead of being silently replaced with an empty vault.

On the first 0.1.1 unlock, an existing 0.1.0 login-Keychain key is migrated only after authentication. The app writes a protected copy, reads it back through biometric authentication, verifies that the keys match, and then removes the legacy item. Cancellation, missing entitlements, conflicting keys, and failed cleanup stop unlock. An existing vault with no key never gets a replacement key generated.

Once migration succeeds, version 0.1.0 cannot unlock the vault. Do not downgrade after migrating. The encrypted vault format does not change. These migration paths pass automated tests with injected Keychain storage; live migration is still awaiting provisioning and a manual Touch ID check.

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

Bundling requires an Apple signing identity and a macOS provisioning profile authorizing `com.termilock.Termilock` and its Keychain access group. A self-signed identity alone cannot enable this protection. Python 3 is required to derive and validate the signing entitlements.

```sh
export TERMILOCK_SIGNING_IDENTITY="Your Apple signing identity"
export TERMILOCK_PROVISIONING_PROFILE="/absolute/path/to/Termilock.provisionprofile"
make bundle
```

The bundle embeds the profile and includes only the required application identifier, team identifier, and Keychain access-group entitlements. Missing signing configuration stops packaging and preserves the previous app bundle. The signing identity must be authorized by the profile. Development profiles may restrict which Macs can run the app.

## Build the installer

After configuring signing:

```sh
make dmg
```

This builds an optimized release app, signs and verifies it, then creates and checks a compressed DMG containing `Termilock.app`, an Applications shortcut, and installation instructions. The version comes from `Resources/Info.plist`; the next output is `dist/Termilock-0.1.1.dmg`. That installer is not available yet.

Generated app bundles and Swift build output are ignored. The versioned DMG is the downloadable artifact. Public distribution still requires appropriate signing and notarization work.

Run the packaging validation tests with:

```sh
python3 Tests/Packaging/test_signing_entitlements.py
```

## Verification status

Version 0.1.1 source passes debug and release compilation, all 25 Swift tests, and 5 provisioning-entitlement validation tests. Missing-profile packaging is rejected before replacing the previous app.

A valid provisioning profile is still required to build the new app bundle and DMG. Real Keychain authentication, migration, cancellation, relock, and macOS 14 runtime behavior have not yet been verified for 0.1.1. The previous 0.1.0 installer passed its checksum, mount, content, and app-signature checks on macOS 26.4.1; those results do not verify the new security implementation.
