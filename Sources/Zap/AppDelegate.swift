import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var hotKeys: [HotKey] = []
    private let controller = SearchPanelController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar agent: no Dock icon, no menu bar takeover.
        NSApp.setActivationPolicy(.accessory)

        let toggle: () -> Void = { [weak self] in
            // Carbon dispatches on the main run loop; hop to the main actor explicitly.
            MainActor.assumeIsolated { self?.controller.toggle() }
        }
        // Register every configured hotkey (defaults: ⌥Space and ⌘Space). Read once at
        // launch, so changing `hotkeys` in config takes effect after a restart.
        let specs = Config.load().resolvedHotKeys()
        hotKeys = specs.enumerated().map { index, spec in
            HotKey(id: UInt32(index + 1), keyCode: spec.keyCode, modifiers: spec.modifiers,
                   name: spec.display, onPress: toggle)
        }

        setupStatusItem(hotkeyLabels: specs.map(\.display))
    }

    private func setupStatusItem(hotkeyLabels: [String]) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "bolt.fill", accessibilityDescription: "Zap")

        let keys = hotkeyLabels.isEmpty ? "hotkey" : hotkeyLabels.joined(separator: " / ")
        let menu = NSMenu()
        menu.addItem(withTitle: "Zap — \(keys) to search", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit Zap", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
    }
}
