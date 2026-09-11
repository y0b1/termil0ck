import XCTest
@testable import Termilock

final class CredentialGeneratorTests: XCTestCase {
    func testPasswordLengthAndCharacterGroups() {
        let password = CredentialGenerator.password(length: 40)

        XCTAssertEqual(password.count, 40)
        XCTAssertNotNil(password.range(of: "[a-z]", options: .regularExpression))
        XCTAssertNotNil(password.range(of: "[A-Z]", options: .regularExpression))
        XCTAssertNotNil(password.range(of: "[0-9]", options: .regularExpression))
        XCTAssertNotNil(password.range(of: "[^A-Za-z0-9]", options: .regularExpression))
    }

    func testUsernameHasThreeParts() {
        XCTAssertEqual(CredentialGenerator.username().split(separator: "-").count, 3)
    }
}
