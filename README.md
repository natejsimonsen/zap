# Zap

A minimal macOS application switcher. Press **⌘Space**, type, hit **Enter** to launch.
It searches only your installed applications — a focused, Spotlight-style launcher and
nothing else. Runs as a menu-bar agent with no Dock icon.

## Features

- Global **⌘Space** hotkey (no Accessibility permission needed — uses Carbon `RegisterEventHotKey`).
- Fuzzy search over `/Applications`, `/System/Applications`, and `~/Applications`
  (including one level of nesting, e.g. `Utilities`).
- Boundary-aware ranking: `sysp` → System Settings, `ps` → Photoshop, prefixes win.
- Keyboard-driven: ↑/↓ to move, Enter to launch, Esc (or click away) to dismiss.
- Re-scans on every open, so newly installed apps show up immediately.

## Build & install

```sh
./build.sh                      # produces ./Zap.app
cp -R Zap.app /Applications/     # install
open /Applications/Zap.app       # launch (a bolt icon appears in the menu bar)
```

Add `/Applications/Zap.app` to **System Settings → General → Login Items** to start it
at login.

## Required one-time setup: free up ⌘Space

macOS assigns ⌘Space to Spotlight by default, and only one app can own a global hotkey.
Turn Spotlight's shortcut off so Zap can claim it:

**System Settings → Keyboard → Keyboard Shortcuts → Spotlight →** uncheck
**"Show Spotlight search"** (⌘Space).

If ⌘Space still opens Spotlight, Zap couldn't register the hotkey — check the shortcut is
really off (Zap logs a message via `NSLog` when registration fails).

## Development

```sh
swift build                  # compile
swift run ZapCoreTests       # run the logic checks (fuzzy matcher + app scanner)
swift run Zap                # run without bundling (Dock icon will appear in this mode)
```

The testable logic lives in the `ZapCore` library (`FuzzyMatcher`, `AppIndex`); the UI,
hotkey, and panel wiring live in the `Zap` executable.

> Note: `swift test` requires a full Xcode toolchain (XCTest/Testing). With Command Line
> Tools only, use `swift run ZapCoreTests` — same coverage, plain-toolchain friendly.
