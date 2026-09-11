import Foundation

@MainActor
final class VaultStore: ObservableObject {
    static let shared = VaultStore()

    @Published private(set) var state: VaultLockState = .locked
    @Published private(set) var document = VaultDocument()
    @Published var saveError: String?

    private let repository: VaultRepository
    private var saveTask: Task<Void, Never>?

    init(repository: VaultRepository = VaultRepository()) {
        self.repository = repository
    }

    deinit {
        saveTask?.cancel()
    }

    func unlock() {
        switch state {
        case .locked, .failed:
            break
        case .unlocking, .locking, .unlocked:
            return
        }
        state = .unlocking
        Task {
            do {
                document = try await repository.unlock()
                state = .unlocked
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }

    func lock() async {
        guard state == .unlocked else { return }
        saveTask?.cancel()
        saveTask = nil
        state = .locking
        let snapshot = document

        do {
            try await repository.save(snapshot)
            saveError = nil
        } catch {
            saveError = error.localizedDescription
            state = .unlocked
            return
        }

        await repository.lock()
        document = VaultDocument()
        state = .locked
    }

    func upsert(_ item: VaultItem) {
        if let index = document.items.firstIndex(where: { $0.id == item.id }) {
            document.items[index] = item
        } else {
            document.items.append(item)
        }
        document.items.sort { $0.platform.localizedStandardCompare($1.platform) == .orderedAscending }
        scheduleSave()
    }

    func delete(_ item: VaultItem) {
        document.items.removeAll { $0.id == item.id }
        scheduleSave()
    }

    func addContact(_ contact: EmergencyContact) {
        document.emergencyContacts.append(contact)
        scheduleSave()
    }

    func deleteContact(_ contact: EmergencyContact) {
        document.emergencyContacts.removeAll { $0.id == contact.id }
        scheduleSave()
    }

    private func scheduleSave() {
        guard state == .unlocked else { return }
        saveTask?.cancel()
        let snapshot = document
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            do {
                try await repository.save(snapshot)
                saveError = nil
            } catch {
                saveError = error.localizedDescription
            }
        }
    }
}
