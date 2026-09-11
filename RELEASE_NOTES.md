# Release notes

## 0.1.1 — Unreleased; provisioning required

Implements Keychain-enforced biometric protection while retaining AES-256-GCM vault encryption.

- Moves vault keys into the Data Protection Keychain with device-only accessibility and synchronization disabled.
- Requires biometrics through Keychain access control, preserving the Touch ID-only policy.
- Migrates the existing key only after reading back and verifying the protected copy; preserves the legacy copy if verification fails.
- Stops on authentication, entitlement, key-conflict, and cleanup errors without falling back to unprotected storage.
- Refuses to generate a new key when an existing vault is missing its key.
- Clears any previous repository key before an unlock attempt.
- Requires a provisioned Apple signing identity for bundling, and rejects stale or unprovisioned bundles during DMG packaging.

**Validation:** debug and release builds pass; 25 Swift tests and 5 signing-entitlement tests pass. Migration tests use injected storage, not the user's Keychain.

**Release blocker:** no macOS provisioning profile is installed for this app. A 0.1.1 DMG has not been produced. Real-device Keychain and Touch ID verification remains pending. The 0.1.0 DMG below is unchanged and does not contain this fix.

**Migration compatibility:** after successful migration, the old 0.1.0 app cannot access the protected key. Do not downgrade. The encrypted vault file format is unchanged.


## 0.1.0 — September 11, 2026

Termilock's first packaged local development release brings a compact credential vault to the macOS menu bar, with a drag-to-Applications installer.

[Download Termilock-0.1.0.dmg](dist/Termilock-0.1.0.dmg)

### Included

- Local vault encrypted with authenticated AES-GCM and a random 256-bit key in the macOS login Keychain.
- App-level Touch ID authentication before reading the vault key, with no login-password fallback.
- Add, edit, delete, and search credentials by platform or username.
- Masked passwords with explicit reveal and copy controls.
- Fixed Platform, User, Password, and Copy columns with wrapping rows.
- Password and username generators.
- Automatic saves and explicit relocking that saves pending changes and clears the unlocked vault from memory.
- Clipboard clearing after 30 seconds while the app is running, without overwriting subsequently copied content.
- Encrypted local trusted-contact designations and capability status for future passkey and emergency-access support.
- Optimized app bundle, versioned DMG, Applications shortcut, and installation instructions. Developers can reproduce the installer with `make dmg`.

### Installation

Requires macOS 14 or newer, Apple Silicon, and available Touch ID. Open the DMG, drag Termilock into Applications, then launch it. The app appears in the menu bar.

For startup at sign-in, add Termilock to **Open at Login** in System Settings. See the [README](README.md) for usage and build instructions.

### Verified

- `swift build`, `swift test`, `make bundle`, and `make dmg` succeeded.
- All 9 tests passed, covering credential generation, biometric policy, rejected authentication, encryption round trips, tamper rejection, encrypted persistence, damaged-vault handling, and relock persistence.
- DMG checksum and read-only mount checks passed; the mounted image contains the app and Applications shortcut.
- The bundled app's signature and property list passed verification. The binary is arm64.
- Termilock was confirmed running on macOS 26.4.1.

### Known limitations

- This DMG uses a local development signing identity and is not notarized for public distribution.
- Touch ID is enforced at the app level. Device-only accessibility and Keychain-enforced user-presence protection required by the contributor guide remain unimplemented.
- Real passkey storage and authentication are unavailable.
- Trusted contacts cannot request or recover access; notifications, waiting periods, and approvals are not active.
- Interactive Touch ID and credential flows still need manual verification. macOS 14 is the deployment minimum, but runtime behavior on that version was not checked in this release verification.

The encrypted vault remains at `~/Library/Application Support/Termilock/vault.tlvault`. Its matching Keychain key is required to decrypt it; retain both when preserving access to existing data.
