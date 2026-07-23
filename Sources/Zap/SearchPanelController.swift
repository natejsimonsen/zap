import AppKit
import SwiftUI

/// A borderless panel that can take keyboard focus and dismisses itself when it
/// loses key status (click-away / app switch), mirroring Spotlight's behaviour.
final class KeyablePanel: NSPanel {
    var onResignKey: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override func resignKey() {
        super.resignKey()
        onResignKey?()
    }
}

/// Owns the search panel and toggles its visibility in response to the hotkey.
@MainActor
final class SearchPanelController {
    let model = LauncherModel()
    private var panel: KeyablePanel?

    init() {
        model.onClose = { [weak self] in self?.hide() }
    }

    func toggle() {
        if panel?.isVisible == true {
            hide()
        } else {
            show()
        }
    }

    func show() {
        model.reload()
        model.query = ""
        model.selection = 0

        let panel = panel ?? makePanel()
        self.panel = panel

        position(panel)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> KeyablePanel {
        let hosting = NSHostingView(rootView: SearchView(model: model))
        hosting.setFrameSize(hosting.fittingSize)

        let panel = KeyablePanel(
            contentRect: NSRect(origin: .zero, size: hosting.fittingSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false)
        panel.contentView = hosting
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false // shadow drawn by the SwiftUI card
        panel.level = .modalPanel
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.onResignKey = { [weak self] in self?.hide() }
        return panel
    }

    /// Centre horizontally, sitting slightly above the vertical centre of the
    /// active screen (where Spotlight appears).
    private func position(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        let x = visible.midX - size.width / 2
        let y = visible.midY - size.height / 2 + visible.height * 0.15
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
