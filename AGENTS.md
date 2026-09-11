# Termilock contributor guide

## Purpose

Termilock is a focused macOS menu-bar password vault for developers and vibecoders. Its primary loop is unlock, find a credential, copy the required value, and dismiss. Keep it compact; do not turn it into a general productivity suite.

## Security invariants

- Never store passwords, generated secrets, vault keys, or emergency-recovery material as plaintext on disk, in `UserDefaults`, logs, crash messages, analytics, fixtures, screenshots, or source code.
- Encrypt the vault with authenticated encryption. Keep its random encryption key in Keychain with device-only accessibility and user-presence protection.
- Never silently replace an unreadable or authentication-failed vault with an empty one.
- Mask passwords by default. Reveal and copy actions must be explicit.
- Clear copied secrets from the pasteboard after a short delay, but only if the pasteboard still contains the value Termilock placed there.
- Keep development samples out of the production vault.
- Security-sensitive changes require tests and review of failure paths.

## Table behavior

- Keep the Platform, User, Password, and Copy columns structurally fixed.
- Content wraps inside its existing cell and grows the row vertically. It must never push or move a column divider.
- Use full-height structural dividers and monospaced data text.

## Passkeys

- Do not model a passkey as a stored password or exportable private-key string.
- Real third-party passkey support requires an AuthenticationServices credential-provider extension, Apple entitlements, signing, and WebAuthn request handling.
- Until that extension exists, the app may expose capability status and implementation guidance but must not claim that passkeys can be stored or used.

## Emergency access

- A trusted contact designation may be stored inside the encrypted local vault.
- A real request, delay, approval/denial, notification, and recovery workflow requires a backend and a reviewed end-to-end encrypted key-release protocol.
- The server must never receive vault plaintext or an unwrapped vault key. Do not ship a simulated request flow as if it were operational.

## Build and verification

- Build with `swift build` and test with `swift test`.
- Bundle with `make bundle`.
- Keep macOS 14 as the minimum unless a product decision changes it.
