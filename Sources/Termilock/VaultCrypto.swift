import CryptoKit
import Foundation

enum VaultCryptoError: LocalizedError {
    case malformedCiphertext

    var errorDescription: String? {
        "The vault file is damaged or is not a Termilock vault."
    }
}

enum VaultCrypto {
    private static let authenticatedData = Data("TermilockVault/v1".utf8)

    static func seal(_ plaintext: Data, using key: SymmetricKey) throws -> Data {
        let box = try AES.GCM.seal(plaintext, using: key, authenticating: authenticatedData)
        guard let combined = box.combined else {
            throw VaultCryptoError.malformedCiphertext
        }
        return combined
    }

    static func open(_ ciphertext: Data, using key: SymmetricKey) throws -> Data {
        let box: AES.GCM.SealedBox
        do {
            box = try AES.GCM.SealedBox(combined: ciphertext)
        } catch {
            throw VaultCryptoError.malformedCiphertext
        }
        return try AES.GCM.open(box, using: key, authenticating: authenticatedData)
    }
}
