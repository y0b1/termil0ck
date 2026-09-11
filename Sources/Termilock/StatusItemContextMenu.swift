@preconcurrency import AppKit

@MainActor
final class StatusItemContextMenu: NSObject {
    private var eventMonitor: Any?

    func start() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.rightMouseDown, .leftMouseDown]
        ) { [weak self] event in
            guard let self else { return event }
            let isContextClick = event.type == .rightMouseDown
                || (event.type == .leftMouseDown && event.modifierFlags.contains(.control))
            guard isContextClick else { return event }

            let handled = MainActor.assumeIsolated {
                guard let button = self.statusItemButton(),
                      button.window?.windowNumber == event.windowNumber,
                      button.bounds.contains(button.convert(event.locationInWindow, from: nil)) else {
                    return false
                }

                self.showMenu(from: button)
                return true
            }
            return handled ? nil : event
        }
    }

    func stop() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
        eventMonitor = nil
    }

    private func showMenu(from button: NSButton) {
        let menu = NSMenu()
        let quitItem = NSMenuItem(
            title: "Force Quit Termilock",
            action: #selector(forceQuit),
            keyEquivalent: ""
        )
        quitItem.target = self
        menu.addItem(quitItem)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY), in: button)
    }

    private func statusItemButton() -> NSButton? {
        for window in NSApp.windows
        where window.frame.height <= 40
            && (window.level == .statusBar || String(describing: type(of: window)).contains("StatusBar")) {
            if let button = findButton(in: window.contentView) {
                return button
            }
        }
        return nil
    }

    private func findButton(in view: NSView?) -> NSButton? {
        guard let view else { return nil }
        if let button = view as? NSButton { return button }
        for subview in view.subviews {
            if let button = findButton(in: subview) { return button }
        }
        return nil
    }

    @objc private func forceQuit() {
        NSApp.terminate(nil)
    }
}
