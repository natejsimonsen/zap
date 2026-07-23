# Architecture

Zap is a Swift Package with two targets: a dependency-free, unit-tested core library
(`ZapCore`) and a thin AppKit/SwiftUI executable (`Zap`) that wires it to the UI.

```
┌─────────────────────────── Zap (executable) ───────────────────────────┐
│  main.swift            NSApplication bootstrap (.accessory policy)       │
│  AppDelegate           menu-bar item + global hotkey registration       │
│  HotKey                Carbon RegisterEventHotKey wrapper (⌘Space)       │
│  SearchPanelController borderless key-capable NSPanel; show/hide/toggle  │
│  SearchView            SwiftUI card: search field + results list        │
│  SearchField           NSTextField bridge (reliable ↑/↓/⏎/⎋ handling)   │
│  LauncherModel         ObservableObject: query → results, launch action │
└──────────────────────────────────┬──────────────────────────────────────┘
                                    │ uses
┌───────────────────────────── ZapCore (library) ─────────────────────────┐
│  AppIndex              scan app dirs → [AppEntry] (name, url)            │
│  FuzzyMatcher          subsequence match + boundary-aware scoring        │
│  Config                ~/.config/zap/config.json model (JSON, defaulted) │
│  Appearance            RGBAColor parser + Density → LayoutMetrics        │
└──────────────────────────────────────────────────────────────────────────┘
```

## Flow

1. `AppDelegate` sets the app to `.accessory` (menu-bar only), adds a status item, and
   registers two `HotKey`s — ⌥Space and ⌘Space — that both toggle the launcher.
   `RegisterEventHotKey` is used instead of a `CGEventTap` specifically so no
   Accessibility permission is needed. Each `HotKey` filters the shared Carbon handler
   on its own id so one press doesn't trigger both.
2. On the hotkey, `SearchPanelController.toggle()` shows a borderless `NSPanel` centred
   slightly above screen centre. `LauncherModel.reload()` re-reads `Config` and re-scans
   the disk each open (so config edits and newly installed apps take effect immediately);
   the panel resizes to the config's density on show.
3. Typing flows through `SearchField` (an `NSTextField` wrapped in `NSViewRepresentable`)
   into `LauncherModel.query`. Its `didSet` calls `recompute()`, which filters `AppIndex`
   results through `FuzzyMatcher` and re-sorts by score.
4. `SearchView` renders the ranked list. ↑/↓ move the selection; Enter calls
   `NSWorkspace.open` on the selected bundle and dismisses the panel.

## Why the split

`AppIndex` and `FuzzyMatcher` are pure logic with no UI dependency, so they're tested in
isolation by the `ZapCoreTests` executable (a plain assertion runner — the Command Line
Tools toolchain ships no XCTest module). The `Zap` target holds everything that touches
AppKit/SwiftUI and is verified manually.

## Testing note

Two subtle bugs are guarded by design here:

- **Stale results:** the SwiftUI `ForEach` uses the app URL as its identity and does **not**
  carry an explicit `.id(index)` — an earlier version did, which conflicted with the
  `ForEach` identity and made SwiftUI reuse rows (showing unfiltered apps) when results changed.
- **Missing system apps:** the scanner does **not** pass `.skipsHiddenFiles`, because Safari
  and friends are hidden symlinks into `/System/Cryptexes`. Dotfiles are filtered manually.
