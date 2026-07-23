import AppKit
import Carbon.HIToolbox

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var hotKey: HotKey?
    private let controller = SearchPanelController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar agent: no Dock icon, no menu bar takeover.
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()

        hotKey = HotKey(keyCode: UInt32(kVK_Space), modifiers: UInt32(cmdKey)) { [weak self] in
            // Carbon dispatches on the main run loop; hop to the main actor explicitly.
            MainActor.assumeIsolated {
                self?.controller.toggle()
            }
        }
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "bolt.fill", accessibilityDescription: "Zap")

        let menu = NSMenu()
        menu.addItem(withTitle: "Zap — Cmd+Space to search", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit Zap", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
    }
}
