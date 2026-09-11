import CryptoKit
import Foundation

actor VaultRepository {
    private let fileURL: URL
    private let keyProvider: any VaultKeyProviding
    private var unlockedKey: SymmetricKey?

    init(fileURL: URL? = nil, keyProvider: any VaultKeyProviding = KeychainKeyProvider()) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.fileURL = support
                .appendingPathComponent("Termilock", isDirectory: true)
                .appendingPathComponent("vault.tlvault", isDirectory: false)
        }
        self.keyProvider = keyProvider
    }

    func unlock() async throws -> VaultDocument {
        let key = try await keyProvider.loadOrCreateKey()

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            unlockedKey = key
            return VaultDocument()
        }

        let ciphertext = try Data(contentsOf: fileURL)
        let plaintext = try VaultCrypto.open(ciphertext, using: key)
        let document = try JSONDecoder.vault.decode(VaultDocument.self, from: plaintext)
        unlockedKey = key
        return document
    }

    func save(_ document: VaultDocument) throws {
        guard let key = unlockedKey else {
            throw RepositoryError.locked
        }
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let plaintext = try JSONEncoder.vault.encode(document)
        let ciphertext = try VaultCrypto.seal(plaintext, using: key)
        try ciphertext.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }

    func lock() {
        unlockedKey = nil
    }
}

enum RepositoryError: LocalizedError {
    case locked

    var errorDescription: String? {
        "The vault is locked. Unlock it before saving."
    }
}

private extension JSONEncoder {
    static var vault: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var vault: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
