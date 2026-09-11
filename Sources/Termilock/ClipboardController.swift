import AppKit
import Foundation

@MainActor
final class ClipboardController: ObservableObject {
    @Published private(set) var copiedLabel: String?
    private var clearTask: Task<Void, Never>?

    func copy(_ value: String, label: String) {
        guard !value.isEmpty else { return }
        clearTask?.cancel()

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
        let changeCount = pasteboard.changeCount
        copiedLabel = label

        clearTask = Task {
            try? await Task.sleep(for: .seconds(30))
            guard !Task.isCancelled else { return }
            if pasteboard.changeCount == changeCount,
               pasteboard.string(forType: .string) == value {
                pasteboard.clearContents()
            }
            copiedLabel = nil
        }
    }
}
