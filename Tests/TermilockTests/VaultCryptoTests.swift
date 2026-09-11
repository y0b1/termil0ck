import CryptoKit
import Foundation
import XCTest
@testable import Termilock

final class VaultCryptoTests: XCTestCase {
    func testEncryptionRoundTrip() throws {
        let key = SymmetricKey(size: .bits256)
        let plaintext = Data("platform|user|secret".utf8)

        let ciphertext = try VaultCrypto.seal(plaintext, using: key)

        XCTAssertNotEqual(ciphertext, plaintext)
        XCTAssertEqual(try VaultCrypto.open(ciphertext, using: key), plaintext)
    }

    func testTamperingIsRejected() throws {
        let key = SymmetricKey(size: .bits256)
        var ciphertext = try VaultCrypto.seal(Data("secret".utf8), using: key)
        ciphertext[ciphertext.startIndex] ^= 1

        XCTAssertThrowsError(try VaultCrypto.open(ciphertext, using: key))
    }

    func testRepositoryPersistsEncryptedDocument() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("vault.tlvault")
        let repository = VaultRepository(fileURL: file, keyProvider: InMemoryKeyProvider())
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let expected = VaultDocument(items: [
            VaultItem(
                platform: "example.test",
                username: "builder",
                password: "not-plaintext",
                createdAt: timestamp,
                updatedAt: timestamp
            )
        ])

        _ = try await repository.unlock()
        try await repository.save(expected)
        let diskBytes = try Data(contentsOf: file)
        XCTAssertNil(String(data: diskBytes, encoding: .utf8)?.range(of: "not-plaintext"))

        await repository.lock()
        let reopened = try await repository.unlock()
        XCTAssertEqual(reopened, expected)
    }

    func testDamagedVaultDoesNotLeaveRepositoryWritable() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("vault.tlvault")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let damagedBytes = Data("not-a-vault".utf8)
        try damagedBytes.write(to: file)
        let repository = VaultRepository(fileURL: file, keyProvider: InMemoryKeyProvider())

        do {
            _ = try await repository.unlock()
            XCTFail("Opening damaged ciphertext should fail")
        } catch {
            // Expected: authentication or ciphertext parsing must reject the file.
        }

        do {
            try await repository.save(VaultDocument())
            XCTFail("A failed unlock must not leave the repository writable")
        } catch RepositoryError.locked {
            // Expected.
        } catch {
            XCTFail("Expected a locked repository, got \(error)")
        }
        XCTAssertEqual(try Data(contentsOf: file), damagedBytes)
    }
}
