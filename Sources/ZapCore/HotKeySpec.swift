import Foundation

/// A parsed hotkey: a Carbon modifier mask plus a virtual key code. Parsing lives here
/// (not in the app layer) so it's testable; the numeric constants match Carbon's
/// `cmdKey`/`optionKey`/… and the standard ANSI virtual key codes, so the app can pass
/// them straight to `RegisterEventHotKey` without a translation table.
public struct HotKeySpec: Equatable {
    public let modifiers: UInt32
    public let keyCode: UInt32
    /// Human-readable label, e.g. "⌥Space".
    public let display: String

    // Carbon modifier masks (Carbon.HIToolbox).
    public static let cmd: UInt32 = 0x0100
    public static let shift: UInt32 = 0x0200
    public static let option: UInt32 = 0x0800
    public static let control: UInt32 = 0x1000

    /// Parse strings like "cmd+space", "opt+space", "ctrl+shift+k". Case-insensitive,
    /// modifiers in any order. Returns nil if there isn't exactly one known key, or an
    /// unknown token appears.
    public init?(string raw: String) {
        let tokens = raw.lowercased().split(separator: "+").map { $0.trimmingCharacters(in: .whitespaces) }
        guard !tokens.isEmpty else { return nil }

        var mods: UInt32 = 0
        var key: (code: UInt32, label: String)?
        for token in tokens where !token.isEmpty {
            if let m = HotKeySpec.modifierMasks[token] {
                mods |= m
            } else if let code = HotKeySpec.keyCodes[token] {
                if key != nil { return nil } // more than one non-modifier key
                key = (code, HotKeySpec.keyLabels[token] ?? token.uppercased())
            } else {
                return nil // unknown token
            }
        }
        guard let key else { return nil }

        var label = ""
        if mods & HotKeySpec.control != 0 { label += "⌃" }
        if mods & HotKeySpec.option != 0 { label += "⌥" }
        if mods & HotKeySpec.shift != 0 { label += "⇧" }
        if mods & HotKeySpec.cmd != 0 { label += "⌘" }
        label += key.label

        self.modifiers = mods
        self.keyCode = key.code
        self.display = label
    }

    private static let modifierMasks: [String: UInt32] = [
        "cmd": cmd, "command": cmd, "⌘": cmd,
        "shift": shift, "⇧": shift,
        "opt": option, "option": option, "alt": option, "⌥": option,
        "ctrl": control, "control": control, "⌃": control,
    ]

    /// Standard ANSI virtual key codes.
    private static let keyCodes: [String: UInt32] = {
        var m: [String: UInt32] = [
            "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
            "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "o": 31, "u": 32,
            "i": 34, "p": 35, "l": 37, "j": 38, "k": 40, "n": 45, "m": 46,
            "1": 18, "2": 19, "3": 20, "4": 21, "5": 23, "6": 22, "7": 26, "8": 28, "9": 25, "0": 29,
            "space": 49, "return": 36, "enter": 36, "tab": 48, "escape": 53, "esc": 53,
        ]
        return m
    }()

    private static let keyLabels: [String: String] = [
        "space": "Space", "return": "Return", "enter": "Return",
        "tab": "Tab", "escape": "Esc", "esc": "Esc",
    ]
}
