# Zap ⚡

A minimal macOS application launcher. Press **⌥Space** (or **⌘Space**), type, hit **Enter**
to launch. It searches *only* your installed applications — a focused, Spotlight-style
launcher and nothing else. Runs as a menu-bar agent with no Dock icon.

![Zap searching for applications](docs/demo.gif)

## Features

- Global **⌥Space** and **⌘Space** hotkeys — no Accessibility permission required
  (Carbon `RegisterEventHotKey`). ⌥Space works immediately; ⌘Space needs Spotlight freed.
- Fuzzy search over `/Applications`, `/System/Applications`, and `~/Applications`
  (including one nested level, e.g. `Utilities`, and hidden system apps like Safari).
- Boundary-aware ranking: `sysp` → System Settings, `ps` → Photoshop, prefixes win.
- Keyboard-driven: ↑/↓ to move, Enter to launch, Esc (or click away) to dismiss.
- Re-scans on every open, so newly installed apps appear immediately.

## Install

### Homebrew

```sh
brew tap natejsimonsen/zap https://github.com/natejsimonsen/zap
brew install --cask natejsimonsen/zap/zap
```

> Use the fully-qualified `natejsimonsen/zap/zap` — the bare `zap` cask name is
> already taken by an unrelated tool in Homebrew's main cask repo.

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

## Hotkeys

Zap binds **⌥Space** and **⌘Space**, and either one toggles it.

- **⌥Space** is free by default, so Zap works right away with no setup.
- **⌘Space** is owned by Spotlight. To use it, free it first:
  **System Settings → Keyboard → Keyboard Shortcuts → Spotlight →** uncheck
  **"Show Spotlight search"** (⌘Space).

Zap logs a message via `NSLog` if it can't register a hotkey another app already owns.

## Configuration

Zap runs with sensible defaults and needs no config. To customize, create
`~/.config/zap/config.json` — all keys are optional, and a missing or malformed file
falls back to defaults:

```json
{
  "searchPaths": ["~/Developer/Apps", "/opt/homebrew/Caskroom"],
  "accentColor": "purple",
  "transparency": 0.8,
  "density": "comfortable"
}
```

| Key | Values | Default | Effect |
|-----|--------|---------|--------|
| `searchPaths` | list of dirs (`~` allowed) | `[]` | Extra folders to scan, **added** to the built-in defaults |
| `accentColor` | hex (`#RRGGBB`, `#RGB`, `#RRGGBBAA`) or a name: `blue` `purple` `pink` `red` `orange` `yellow` `green` `teal` `graphite` | system accent | Selection highlight color |
| `transparency` | `0.0`–`1.0` | `0.8` | `0` = opaque, `1` = maximum blur / most see-through |
| `density` | `compact` \| `simple` \| `comfortable` | `comfortable` | Row spacing, font, icon, and window size |

Changes take effect the next time you open the launcher — no restart needed.

## Usage

| Key | Action |
|-----|--------|
| ⌥Space / ⌘Space | Toggle the launcher |
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
