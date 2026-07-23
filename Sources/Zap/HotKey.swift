import AppKit
import Carbon.HIToolbox

/// A single global hotkey registered via Carbon's `RegisterEventHotKey`.
///
/// This deliberately avoids CGEventTap, so no Accessibility permission is required.
/// Registration fails silently if another app (e.g. Spotlight) already owns the combo.
final class HotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let onPress: () -> Void

    /// - Parameters:
    ///   - keyCode: a virtual key code (e.g. `kVK_Space`).
    ///   - modifiers: Carbon modifier mask (e.g. `cmdKey`).
    init(keyCode: UInt32, modifiers: UInt32, onPress: @escaping () -> Void) {
        self.onPress = onPress

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed))

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let me = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
            me.onPress()
            return noErr
        }, 1, &eventType, selfPtr, &eventHandler)

        let hotKeyID = EventHotKeyID(signature: OSType(0x5A415021 /* "ZAP!" */), id: 1)
        let status = RegisterEventHotKey(
            keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        if status != noErr {
            NSLog("Zap: failed to register hotkey (status \(status)). Is Cmd+Space still bound to Spotlight?")
        }
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }
}
