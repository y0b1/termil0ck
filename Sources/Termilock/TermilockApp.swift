import AppKit
import SwiftUI

@main
struct TermilockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = VaultStore.shared
    @StateObject private var clipboard = ClipboardController()

    var body: some Scene {
        MenuBarExtra {
            VaultView()
                .environmentObject(store)
                .environmentObject(clipboard)
        } label: {
            Label("Termilock", systemImage: "lock.shield.fill")
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemContextMenu: StatusItemContextMenu?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        VaultStore.shared.unlock()
        statusItemContextMenu = StatusItemContextMenu()
        statusItemContextMenu?.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusItemContextMenu?.stop()
    }
}
