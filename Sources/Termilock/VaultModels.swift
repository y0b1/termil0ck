import Foundation

struct VaultItem: Codable, Identifiable, Equatable, Sendable {
    var id: UUID = UUID()
    var platform: String
    var username: String
    var password: String
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
}

struct EmergencyContact: Codable, Identifiable, Equatable, Sendable {
    var id: UUID = UUID()
    var name: String
    var email: String
    var waitingPeriodDays: Int = 7
    var createdAt: Date = Date()
}

struct VaultDocument: Codable, Equatable, Sendable {
    var version = 1
    var items: [VaultItem] = []
    var emergencyContacts: [EmergencyContact] = []
}

enum VaultLockState: Equatable {
    case locked
    case unlocking
    case locking
    case unlocked
    case failed(String)
}
