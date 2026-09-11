import LocalAuthentication
import XCTest
@testable import Termilock

final class KeychainKeyProviderTests: XCTestCase {
    func testLocalAuthenticationIsBiometricsOnly() {
        XCTAssertEqual(
            LocalDeviceAuthenticator.policy,
            .deviceOwnerAuthenticationWithBiometrics
        )
    }

    func testAuthenticationFailureStopsBeforeKeychainAccess() async {
        let provider = KeychainKeyProvider(authenticator: RejectingAuthenticator())

        do {
            _ = try await provider.loadOrCreateKey()
            XCTFail("A rejected device-owner check must stop Keychain access")
        } catch TestAuthenticationError.rejected {
            // Expected.
        } catch {
            XCTFail("Expected the authentication failure, got \(error)")
        }
    }
}

private enum TestAuthenticationError: Error {
    case rejected
}

private struct RejectingAuthenticator: DeviceAuthenticating {
    func authenticate() async throws {
        throw TestAuthenticationError.rejected
    }
}
