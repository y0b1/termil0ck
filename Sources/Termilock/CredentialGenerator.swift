import Foundation

enum CredentialGenerator {
    private static let lowercase = Array("abcdefghijkmnopqrstuvwxyz")
    private static let uppercase = Array("ABCDEFGHJKLMNPQRSTUVWXYZ")
    private static let numbers = Array("23456789")
    private static let symbols = Array("!@#$%^&*-_=+?")

    static func password(length: Int = 24) -> String {
        let safeLength = min(max(length, 12), 128)
        let groups = [lowercase, uppercase, numbers, symbols]
        var result = groups.compactMap { $0.randomElement() }
        let all = groups.flatMap { $0 }
        while result.count < safeLength {
            if let next = all.randomElement() { result.append(next) }
        }
        result.shuffle()
        return String(result)
    }

    static func username() -> String {
        let adjectives = [
            "amber", "atomic", "brisk", "cobalt", "cosmic", "quiet", "rapid", "solar",
            "steady", "velvet"
        ]
        let nouns = [
            "atlas", "badger", "cipher", "comet", "falcon", "forge", "orbit", "otter",
            "signal", "vertex"
        ]
        let number = Int.random(in: 1000...9999)
        return "\(adjectives.randomElement()!)-\(nouns.randomElement()!)-\(number)"
    }
}
