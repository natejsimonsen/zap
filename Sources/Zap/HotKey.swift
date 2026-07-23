import AppKit
import Carbon.HIToolbox

/// A single global hotkey registered via Carbon's `RegisterEventHotKey`.
///
/// This deliberately avoids CGEventTap, so no Accessibility permission is required.
/// Registration fails silently if another app (e.g. Spotlight) already owns the combo.
///
/// Each instance installs its own event handler; because the handler fires for every
/// registered hotkey, it filters on the instance's unique `id` so two hotkeys don't
/// both react to a single press.
final class HotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let onPress: () -> Void
    private let id: UInt32
    private let name: String

    /// - Parameters:
    ///   - id: a unique identifier distinguishing this hotkey from others.
    ///   - keyCode: a virtual key code (e.g. `kVK_Space`).
    ///   - modifiers: Carbon modifier mask (e.g. `cmdKey`, `optionKey`).
    ///   - name: human-readable label used in failure logging.
    init(id: UInt32, keyCode: UInt32, modifiers: UInt32, name: String, onPress: @escaping () -> Void) {
        self.id = id
        self.name = name
        self.onPress = onPress

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed))

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let userData, let event else { return noErr }
            let me = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
            var firedID = EventHotKeyID()
            let status = GetEventParameter(
                event, EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID), nil,
                MemoryLayout<EventHotKeyID>.size, nil, &firedID)
            if status == noErr, firedID.id == me.id {
                me.onPress()
            }
            return noErr
        }, 1, &eventType, selfPtr, &eventHandler)

        let hotKeyID = EventHotKeyID(signature: OSType(0x5A415021 /* "ZAP!" */), id: id)
        let status = RegisterEventHotKey(
            keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        if status != noErr {
            NSLog("Zap: failed to register \(name) hotkey (status \(status)); another app may own it.")
        }
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }
}
