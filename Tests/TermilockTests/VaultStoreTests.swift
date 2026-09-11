import Foundation
import XCTest
@testable import Termilock

final class VaultStoreTests: XCTestCase {
    @MainActor
    func testRelockFlushesLatestDocumentAndClearsMemory() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("vault.tlvault")
        let repository = VaultRepository(fileURL: file, keyProvider: InMemoryKeyProvider())
        let store = VaultStore(repository: repository)

        store.unlock()
        for _ in 0..<100 where store.state != .unlocked {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(store.state, .unlocked)

        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let item = VaultItem(
            platform: "example.test",
            username: "builder",
            password: "secret",
            createdAt: timestamp,
            updatedAt: timestamp
        )
        store.upsert(item)
        await store.lock()

        XCTAssertEqual(store.state, .locked)
        XCTAssertTrue(store.document.items.isEmpty)

        let reopened = try await repository.unlock()
        XCTAssertEqual(reopened.items, [item])
    }
}
