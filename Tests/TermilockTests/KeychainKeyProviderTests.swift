import CryptoKit
import LocalAuthentication
import Security
import XCTest
@testable import Termilock

final class KeychainKeyProviderTests: XCTestCase {
    func testProtectionRequiresDeviceOnlyStorageAndBiometrics() {
        XCTAssertEqual(SystemVaultKeyStorage.protection, kSecAttrAccessibleWhenUnlockedThisDeviceOnly)
        XCTAssertEqual(SystemVaultKeyStorage.constraints, .biometryAny)
        XCTAssertEqual(LocalDeviceAuthenticator.policy, .deviceOwnerAuthenticationWithBiometrics)
    }

    func testNativeAddRequestUsesProtectedNonSyncingKeychain() throws {
        let request = try SystemVaultKeyStorage().protectedAddRequest(randomKey())
        XCTAssertEqual(request[kSecUseDataProtectionKeychain] as? Bool, true)
        XCTAssertEqual(request[kSecAttrSynchronizable] as? Bool, false)
        XCTAssertNotNil(request[kSecAttrAccessControl])
        XCTAssertNil(request[kSecAttrAccessible]) // Accessibility is set within the access control.
        XCTAssertEqual(request[kSecAttrService] as? String, "com.termilock.Termilock.vault-key.protected-v1")
    }

    func testAuthenticationFailureStopsBeforeLegacyAccess() async {
        let storage = TestKeyStorage()
        let provider = KeychainKeyProvider(authenticator: RejectingAuthenticator(), storage: storage)
        do {
            _ = try await provider.loadOrCreateKey()
            XCTFail("Authentication must fail")
        } catch TestAuthenticationError.rejected {
        } catch { XCTFail("Unexpected error type") }
        XCTAssertEqual(storage.events, ["readProtected"])
    }

    func testMissingEntitlementNeverFallsBackToLegacy() async {
        let storage = TestKeyStorage()
        storage.readError = .status(errSecMissingEntitlement)
        await expectFailure(storage)
        XCTAssertEqual(storage.events, ["readProtected"])
    }

    func testCancelledProtectedReadNeverFallsBackToLegacy() async {
        let storage = TestKeyStorage()
        storage.readError = .status(errSecUserCanceled)
        await expectFailure(storage)
        XCTAssertEqual(storage.events, ["readProtected"])
    }

    func testMigrationVerifiesProtectedCopyBeforeDeletingLegacy() async throws {
        let storage = TestKeyStorage()
        let original = randomKey()
        storage.legacy = original
        let key = try await provider(storage).loadOrCreateKey(allowCreation: false)
        XCTAssertTrue(key.withUnsafeBytes { Data($0) } == original)
        XCTAssertNil(storage.legacy)
        XCTAssertEqual(storage.events, ["readProtected", "readLegacy", "addProtected", "readProtected", "deleteLegacy"])
    }

    func testFailedAddPreservesLegacy() async {
        let storage = TestKeyStorage()
        storage.legacy = randomKey()
        storage.addError = .status(errSecMissingEntitlement)
        await expectFailure(storage)
        XCTAssertNotNil(storage.legacy)
        XCTAssertFalse(storage.events.contains("deleteLegacy"))
    }

    func testCancelledVerificationPreservesLegacy() async {
        let storage = TestKeyStorage()
        storage.legacy = randomKey()
        storage.verificationError = .status(errSecUserCanceled)
        await expectFailure(storage)
        XCTAssertNotNil(storage.legacy)
        XCTAssertFalse(storage.events.contains("deleteLegacy"))
    }

    func testConflictingKeysArePreserved() async {
        let storage = TestKeyStorage()
        storage.protected = randomKey()
        storage.legacy = randomKey()
        await expectFailure(storage)
        XCTAssertNotNil(storage.legacy)
        XCTAssertNotNil(storage.protected)
        XCTAssertFalse(storage.events.contains("deleteLegacy"))
    }

    func testInterruptedMigrationResumesCleanup() async throws {
        let storage = TestKeyStorage()
        storage.protected = randomKey()
        storage.legacy = storage.protected
        _ = try await provider(storage).loadOrCreateKey(allowCreation: false)
        XCTAssertEqual(storage.events, ["readProtected", "readLegacy", "deleteLegacy"])
        XCTAssertNil(storage.legacy)
    }

    func testDeleteFailureDoesNotReportSuccessfulMigration() async {
        let storage = TestKeyStorage()
        storage.legacy = randomKey()
        storage.deleteError = .status(errSecAuthFailed)
        await expectFailure(storage)
        XCTAssertNotNil(storage.legacy)
        XCTAssertNotNil(storage.protected)
    }

    func testExistingVaultCannotCreateReplacementKey() async {
        let storage = TestKeyStorage()
        do {
            _ = try await provider(storage).loadOrCreateKey(allowCreation: false)
            XCTFail("Missing existing key must fail")
        } catch KeychainKeyError.missingKey {
        } catch { XCTFail("Unexpected error type") }
        XCTAssertFalse(storage.events.contains("addProtected"))
    }

    func testNewVaultUsesVerifiedProtectedKey() async throws {
        let storage = TestKeyStorage()
        let key = try await provider(storage).loadOrCreateKey()
        XCTAssertEqual(key.bitCount, 256)
        XCTAssertTrue(key.withUnsafeBytes { Data($0) } == storage.protected)
        XCTAssertEqual(storage.events, ["readProtected", "readLegacy", "addProtected", "readProtected"])
    }

    func testDuplicateCreationReadsWinningKey() async throws {
        let storage = TestKeyStorage()
        storage.concurrentKey = randomKey()
        let key = try await provider(storage).loadOrCreateKey()
        XCTAssertTrue(key.withUnsafeBytes { Data($0) } == storage.concurrentKey)
    }

    func testDuplicateMigrationWithDifferentKeyPreservesLegacy() async {
        let storage = TestKeyStorage()
        storage.legacy = randomKey()
        storage.concurrentKey = randomKey()
        await expectFailure(storage)
        XCTAssertNotNil(storage.legacy)
        XCTAssertFalse(storage.events.contains("deleteLegacy"))
    }

    func testMalformedProtectedKeyStopsMigration() async {
        let storage = TestKeyStorage()
        storage.protected = Data()
        await expectFailure(storage)
        XCTAssertEqual(storage.events, ["readProtected"])
    }

    private func randomKey() -> Data {
        SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
    }

    private func provider(_ storage: TestKeyStorage) -> KeychainKeyProvider {
        KeychainKeyProvider(authenticator: AcceptingAuthenticator(), storage: storage)
    }

    private func expectFailure(_ storage: TestKeyStorage) async {
        do {
            _ = try await provider(storage).loadOrCreateKey()
            XCTFail("Operation must fail closed")
        } catch { }
    }
}

// Each test owns its instance and calls it serially from one task.
private final class TestKeyStorage: VaultKeyStorage, @unchecked Sendable {
    var protected: Data?
    var legacy: Data?
    var concurrentKey: Data?
    var readError: KeychainKeyError?
    var addError: KeychainKeyError?
    var verificationError: KeychainKeyError?
    var deleteError: KeychainKeyError?
    var events: [String] = []

    func readProtected() throws -> Data? {
        events.append("readProtected")
        if let readError { throw readError }
        if events.contains("addProtected"), let verificationError { throw verificationError }
        return protected
    }
    func readLegacy() throws -> Data? {
        events.append("readLegacy")
        return legacy
    }
    func addProtected(_ data: Data) throws {
        events.append("addProtected")
        if let addError { throw addError }
        if let concurrentKey {
            protected = concurrentKey
            throw KeychainKeyError.status(errSecDuplicateItem)
        }
        protected = data
    }
    func deleteLegacy() throws {
        events.append("deleteLegacy")
        if let deleteError { throw deleteError }
        legacy = nil
    }
}

private enum TestAuthenticationError: Error { case rejected }
private struct RejectingAuthenticator: DeviceAuthenticating {
    func authenticate() async throws { throw TestAuthenticationError.rejected }
}
private struct AcceptingAuthenticator: DeviceAuthenticating {
    func authenticate() async throws { }
}
