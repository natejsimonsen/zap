# Zap ⚡

A minimal macOS application launcher. Press **⌘Space**, type, hit **Enter** to launch.
It searches *only* your installed applications — a focused, Spotlight-style launcher and
nothing else. Runs as a menu-bar agent with no Dock icon.

![Zap searching for applications](docs/demo.gif)

## Features

- Global **⌘Space** hotkey — no Accessibility permission required (Carbon `RegisterEventHotKey`).
- Fuzzy search over `/Applications`, `/System/Applications`, and `~/Applications`
  (including one nested level, e.g. `Utilities`, and hidden system apps like Safari).
- Boundary-aware ranking: `sysp` → System Settings, `ps` → Photoshop, prefixes win.
- Keyboard-driven: ↑/↓ to move, Enter to launch, Esc (or click away) to dismiss.
- Re-scans on every open, so newly installed apps appear immediately.

## Install

### Homebrew

```sh
brew tap natejsimonsen/zap https://github.com/natejsimonsen/zap
brew install --cask zap
```

Zap is not notarized, so the first launch triggers Gatekeeper. Either right-click
`Zap.app` in `/Applications` → **Open**, or run `xattr -dr com.apple.quarantine /Applications/Zap.app`.

### Nix

```sh
nix run github:natejsimonsen/zap      # run once
nix profile install github:natejsimonsen/zap   # install
```

### From a release

Download `Zap.zip` from the [latest release](https://github.com/natejsimonsen/zap/releases),
unzip, and move `Zap.app` to `/Applications`.

### From source

```sh
git clone https://github.com/natejsimonsen/zap && cd zap
make install        # builds Zap.app and copies it to /Applications
open /Applications/Zap.app
```

Add `/Applications/Zap.app` to **System Settings → General → Login Items** to start at login.

## Required one-time setup: free up ⌘Space

macOS assigns ⌘Space to Spotlight, and only one app can own a global hotkey. Turn
Spotlight's shortcut off so Zap can claim it:

**System Settings → Keyboard → Keyboard Shortcuts → Spotlight →** uncheck
**"Show Spotlight search"** (⌘Space).

If ⌘Space still opens Spotlight, Zap couldn't register the hotkey — confirm the shortcut
is really off (Zap logs a message via `NSLog` when registration fails).

## Usage

| Key | Action |
|-----|--------|
| ⌘Space | Toggle the launcher |
| type | Fuzzy-filter applications |
| ↑ / ↓ | Move selection |
| Enter | Launch selected app |
| Esc / click away | Dismiss |

## Development

```sh
make            # list targets
make build      # compile a release binary
make test       # run the ZapCore checks
make run        # run without bundling
make app        # build Zap.app
make nix-build  # build via the Nix flake
```

> `swift test` needs a full Xcode toolchain (XCTest/Testing). With Command Line Tools
> only, use `make test` (`swift run ZapCoreTests`) — same coverage, plain-toolchain friendly.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for how it fits together.

## License

MIT — see [LICENSE](LICENSE).
