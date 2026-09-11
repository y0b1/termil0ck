import CryptoKit
import Foundation
import LocalAuthentication
import Security

protocol VaultKeyProviding: Sendable {
    func loadOrCreateKey(allowCreation: Bool) async throws -> SymmetricKey
}

protocol DeviceAuthenticating: Sendable {
    func authenticate() async throws
}

enum DeviceAuthenticationError: LocalizedError {
    case unavailable(String)
    case rejected

    var errorDescription: String? {
        switch self {
        case .unavailable(let message):
            return "Device-owner authentication is unavailable: \(message)"
        case .rejected:
            return "Termilock could not verify the device owner."
        }
    }
}

struct LocalDeviceAuthenticator: DeviceAuthenticating {
    static let policy = LAPolicy.deviceOwnerAuthenticationWithBiometrics

    func authenticate() async throws {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        context.localizedFallbackTitle = ""
        var policyError: NSError?
        guard context.canEvaluatePolicy(Self.policy, error: &policyError) else {
            throw DeviceAuthenticationError.unavailable(
                policyError?.localizedDescription ?? "no authentication method is configured"
            )
        }

        let accepted = try await context.evaluatePolicy(
            Self.policy,
            localizedReason: "Use Touch ID to open your Termilock vault"
        )
        guard accepted else { throw DeviceAuthenticationError.rejected }
    }
}

enum KeychainKeyError: LocalizedError {
    case unexpectedData
    case missingKey
    case migrationConflict
    case accessControlCreation
    case status(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unexpectedData:
            return "The vault key in Keychain has an unexpected format."
        case .missingKey:
            return "The existing vault's key is missing. No replacement key was created."
        case .migrationConflict:
            return "The protected and legacy vault keys differ. Both were preserved; migration was stopped."
        case .accessControlCreation:
            return "macOS could not create biometric protection for the vault key."
        case .status(errSecMissingEntitlement):
            return "This build is not provisioned for protected Keychain access. Install a correctly signed and provisioned Termilock build. Your existing vault and key have not been replaced."
        case .status(let status):
            let detail = SecCopyErrorMessageString(status, nil) as String? ?? "status \(status)"
            return "Keychain access failed: \(detail)"
        }
    }
}

// The migration is injectable so failure paths never touch a real vault in tests.
protocol VaultKeyStorage: Sendable {
    func readProtected() throws -> Data?
    func readLegacy() throws -> Data?
    func addProtected(_ data: Data) throws
    func deleteLegacy() throws
}

struct SystemVaultKeyStorage: VaultKeyStorage {
    static let protection = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    // Preserve the product's Touch ID-only policy. userPresence alone also permits a password.
    static let constraints: SecAccessControlCreateFlags = .biometryAny

    private func query(protected: Bool) -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: protected ? "com.termilock.Termilock.vault-key.protected-v1" : "com.termilock.Termilock.vault-key",
            kSecAttrAccount: "primary-vault",
            kSecUseDataProtectionKeychain: protected
        ]
    }

    func readProtected() throws -> Data? {
        var request = query(protected: true)
        request[kSecAttrSynchronizable] = false
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        context.localizedFallbackTitle = ""
        context.touchIDAuthenticationAllowableReuseDuration = 0
        request[kSecUseAuthenticationContext] = context
        defer { context.invalidate() }
        return try read(request)
    }

    func readLegacy() throws -> Data? {
        try read(query(protected: false))
    }

    private func read(_ query: [CFString: Any]) throws -> Data? {
        var request = query
        request[kSecReturnData] = true
        request[kSecMatchLimit] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainKeyError.status(status) }
        guard let data = item as? Data, data.count == 32 else {
            throw KeychainKeyError.unexpectedData
        }
        return data
    }

    func protectedAddRequest(_ data: Data) throws -> [CFString: Any] {
        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            nil, Self.protection, Self.constraints, &error
        ) else {
            if let error { throw error.takeRetainedValue() as Error }
            throw KeychainKeyError.accessControlCreation
        }
        var request = query(protected: true)
        request[kSecAttrSynchronizable] = false
        request[kSecAttrAccessControl] = access
        request[kSecValueData] = data
        return request
    }

    func addProtected(_ data: Data) throws {
        let request = try protectedAddRequest(data)
        let status = SecItemAdd(request as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainKeyError.status(status) }
    }

    func deleteLegacy() throws {
        let status = SecItemDelete(query(protected: false) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainKeyError.status(status)
        }
    }
}

struct KeychainKeyProvider: VaultKeyProviding {
    private let authenticator: any DeviceAuthenticating
    private let storage: any VaultKeyStorage

    init(
        authenticator: any DeviceAuthenticating = LocalDeviceAuthenticator(),
        storage: any VaultKeyStorage = SystemVaultKeyStorage()
    ) {
        self.authenticator = authenticator
        self.storage = storage
    }

    func loadOrCreateKey(allowCreation: Bool = true) async throws -> SymmetricKey {
        // Errors (including cancellation and missing entitlements) never fall back to legacy access.
        if let protected = try storage.readProtected() {
            try validate(protected)
            // Resume cleanup after an interrupted migration, only after protected authentication.
            if let legacy = try storage.readLegacy() {
                try validate(legacy)
                guard protected == legacy else { throw KeychainKeyError.migrationConflict }
                try storage.deleteLegacy()
            }
            return SymmetricKey(data: protected)
        }

        // Only the unprotected legacy key needs an app-level authentication gate.
        try await authenticator.authenticate()
        let legacy = try storage.readLegacy()
        let candidate: Data
        if let legacy {
            try validate(legacy)
            candidate = legacy
        } else {
            guard allowCreation else { throw KeychainKeyError.missingKey }
            candidate = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
        }

        do {
            try storage.addProtected(candidate)
        } catch KeychainKeyError.status(errSecDuplicateItem) {
            // Another process may have won creation. Read its key; never overwrite it.
        }
        guard let verified = try storage.readProtected() else { throw KeychainKeyError.missingKey }
        try validate(verified)
        if let legacy {
            guard verified == legacy else { throw KeychainKeyError.migrationConflict }
            // Keep the old item until a fresh, biometric-gated read verifies the exact key.
            try storage.deleteLegacy()
        }
        return SymmetricKey(data: verified)
    }

    private func validate(_ data: Data) throws {
        guard data.count == 32 else { throw KeychainKeyError.unexpectedData }
    }
}

struct InMemoryKeyProvider: VaultKeyProviding {
    let data: Data

    init(data: Data = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }) {
        self.data = data
    }

    func loadOrCreateKey(allowCreation: Bool) async throws -> SymmetricKey {
        SymmetricKey(data: data)
    }
}
