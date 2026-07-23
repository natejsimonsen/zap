import AppKit
import Carbon.HIToolbox

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var hotKeys: [HotKey] = []
    private let controller = SearchPanelController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar agent: no Dock icon, no menu bar takeover.
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()

        let toggle: () -> Void = { [weak self] in
            // Carbon dispatches on the main run loop; hop to the main actor explicitly.
            MainActor.assumeIsolated { self?.controller.toggle() }
        }
        // Both hotkeys toggle the launcher. Option+Space works out of the box;
        // Cmd+Space only registers once Spotlight's shortcut is freed.
        hotKeys = [
            HotKey(id: 1, keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey),
                   name: "Option+Space", onPress: toggle),
            HotKey(id: 2, keyCode: UInt32(kVK_Space), modifiers: UInt32(cmdKey),
                   name: "Cmd+Space", onPress: toggle),
        ]
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "bolt.fill", accessibilityDescription: "Zap")

        let menu = NSMenu()
        menu.addItem(withTitle: "Zap — ⌥Space (or ⌘Space) to search", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit Zap", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
    }
}
