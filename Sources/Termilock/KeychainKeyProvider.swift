import CryptoKit
import Foundation
import LocalAuthentication
import Security

protocol VaultKeyProviding: Sendable {
    func loadOrCreateKey() async throws -> SymmetricKey
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
    case status(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unexpectedData:
            return "The vault key in Keychain has an unexpected format."
        case .status(let status):
            let detail = SecCopyErrorMessageString(status, nil) as String? ?? "status \(status)"
            return "Keychain access failed: \(detail)"
        }
    }
}

struct KeychainKeyProvider: VaultKeyProviding {
    private let service = "com.termilock.Termilock.vault-key"
    private let account = "primary-vault"
    private let authenticator: any DeviceAuthenticating

    init(authenticator: any DeviceAuthenticating = LocalDeviceAuthenticator()) {
        self.authenticator = authenticator
    }

    func loadOrCreateKey() async throws -> SymmetricKey {
        try await authenticator.authenticate()

        // Ad-hoc builds cannot claim the restricted data-protection Keychain
        // entitlements. The login Keychain remains local, while explicit
        // LocalAuthentication above preserves the user-presence gate.
        var item: CFTypeRef?
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecSuccess {
            guard let data = item as? Data, data.count == 32 else {
                throw KeychainKeyError.unexpectedData
            }
            return SymmetricKey(data: data)
        }
        guard status == errSecItemNotFound else {
            throw KeychainKeyError.status(status)
        }

        var randomBytes = Data(count: 32)
        let randomStatus = randomBytes.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, 32, buffer.baseAddress!)
        }
        guard randomStatus == errSecSuccess else {
            throw KeychainKeyError.status(randomStatus)
        }

        let addQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: randomBytes
        ]
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus == errSecDuplicateItem {
            var existingItem: CFTypeRef?
            let retryStatus = SecItemCopyMatching(query as CFDictionary, &existingItem)
            guard retryStatus == errSecSuccess else {
                throw KeychainKeyError.status(retryStatus)
            }
            guard let data = existingItem as? Data, data.count == 32 else {
                throw KeychainKeyError.unexpectedData
            }
            return SymmetricKey(data: data)
        }
        guard addStatus == errSecSuccess else {
            throw KeychainKeyError.status(addStatus)
        }
        return SymmetricKey(data: randomBytes)
    }
}

struct InMemoryKeyProvider: VaultKeyProviding {
    let data: Data

    init(data: Data = Data(repeating: 7, count: 32)) {
        self.data = data
    }

    func loadOrCreateKey() async throws -> SymmetricKey {
        SymmetricKey(data: data)
    }
}
