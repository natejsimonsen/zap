import Foundation
import ZapCore

// Minimal assertion harness — no XCTest/Testing dependency so it runs under the
// Command Line Tools toolchain via `swift run ZapCoreTests`.
var failures = 0
func check(_ condition: Bool, _ message: String) {
    if condition {
        print("  ok   \(message)")
    } else {
        failures += 1
        print("  FAIL \(message)")
    }
}

// MARK: FuzzyMatcher

func testFuzzyMatcher() {
    print("FuzzyMatcher")
    check(FuzzyMatcher.score(query: "xyz", in: "Safari") == nil, "non-subsequence is nil")
    check(FuzzyMatcher.score(query: "saff", in: "Safari") == nil, "too-many-chars is nil")
    check(FuzzyMatcher.score(query: "", in: "Anything") != nil, "empty query matches")
    check(FuzzyMatcher.score(query: "SAF", in: "Safari") != nil, "case-insensitive query")
    check(FuzzyMatcher.score(query: "saf", in: "SAFARI") != nil, "case-insensitive candidate")
    check(FuzzyMatcher.score(query: "ps", in: "Photoshop") != nil, "scattered subsequence")

    if let exact = FuzzyMatcher.score(query: "notes", in: "Notes"),
       let prefix = FuzzyMatcher.score(query: "note", in: "Notes"),
       let scattered = FuzzyMatcher.score(query: "nts", in: "Notes") {
        check(exact > prefix, "exact beats prefix")
        check(prefix > scattered, "prefix beats scattered")
    } else {
        check(false, "ranking scores all present")
    }

    if let prefixHit = FuzzyMatcher.score(query: "map", in: "Maps"),
       let midwordHit = FuzzyMatcher.score(query: "map", in: "Google Maps") {
        check(prefixHit > midwordHit, "prefix beats midword")
    } else {
        check(false, "prefix/midword scores present")
    }

    if let boundary = FuzzyMatcher.score(query: "sp", in: "System Preferences"),
       let interior = FuzzyMatcher.score(query: "sp", in: "Inspector") {
        check(boundary > interior, "word-boundary beats interior")
    } else {
        check(false, "boundary/interior scores present")
    }

    check(FuzzyMatcher.matches(query: "saf", in: "Safari"), "matches() true for hit")
    check(!FuzzyMatcher.matches(query: "zzz", in: "Safari"), "matches() false for miss")
}

// MARK: AppIndex

func testAppIndex() {
    print("AppIndex")
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent("zap-test-\(UUID().uuidString)")
    defer { try? fm.removeItem(at: root) }

    func makeBundle(_ path: String, bundleName: String? = nil) {
        let url = root.appendingPathComponent(path)
        try? fm.createDirectory(
            at: url.appendingPathComponent("Contents"), withIntermediateDirectories: true)
        if let bundleName {
            let dict: [String: Any] = ["CFBundleName": bundleName]
            if let data = try? PropertyListSerialization.data(
                fromPropertyList: dict, format: .xml, options: 0) {
                try? data.write(to: url.appendingPathComponent("Contents/Info.plist"))
            }
        }
    }

    makeBundle("Safari.app")
    makeBundle("Notes.app")
    makeBundle(".Trashed.app") // dotfile-prefixed: must be skipped
    makeBundle("Utilities/Terminal.app")
    makeBundle("Xcode.app")
    makeBundle("Xcode.app/Contents/Applications/Instruments.app")
    makeBundle("com.foo.bar.app", bundleName: "Pretty Name")

    let apps = AppIndex.scan(paths: [root, root]) // duplicate path exercises dedup
    let names = apps.map(\.name)

    check(names.contains("Safari"), "finds top-level Safari")
    check(names.contains("Notes"), "finds top-level Notes")
    check(!names.contains(".Trashed"), "skips dotfile-prefixed bundles")
    check(names.contains("Terminal"), "recurses into Utilities")
    check(names.contains("Xcode"), "finds Xcode")
    check(!names.contains("Instruments"), "does not descend into bundle internals")
    check(names.contains("Pretty Name"), "uses CFBundleName display name")
    check(names == names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending },
          "results are sorted")
    check(Set(names).count == names.count, "results are de-duplicated")
}

func testConfig() {
    print("Config")
    let fm = FileManager.default
    let dir = fm.temporaryDirectory.appendingPathComponent("zap-cfg-\(UUID().uuidString)")
    try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: dir) }

    // Missing file → all defaults.
    let missing = Config.load(from: dir.appendingPathComponent("nope.json"))
    check(missing == Config(), "missing file yields default config")
    check(missing.density == .comfortable, "default density is comfortable")
    check(missing.transparency == 0.8, "default transparency is 0.8")

    func write(_ json: String) -> URL {
        let u = dir.appendingPathComponent("\(UUID().uuidString).json")
        try? json.data(using: .utf8)!.write(to: u)
        return u
    }

    // Malformed JSON → defaults, no crash.
    check(Config.load(from: write("{not json")) == Config(), "malformed json yields default config")

    // Full config parses.
    let full = Config.load(from: write("""
    {"searchPaths":["~/Dev/Apps"," "],"accentColor":"purple","transparency":0.5,"density":"compact"}
    """))
    check(full.density == .compact, "parses density")
    check(full.transparency == 0.5, "parses transparency")
    check(full.searchPaths == ["~/Dev/Apps", " "], "parses searchPaths raw")
    check(full.resolvedSearchPaths().count == 1, "blank search paths dropped on resolve")
    check(full.resolvedSearchPaths().first?.path.hasPrefix(fm.homeDirectoryForCurrentUser.path) == true,
          "tilde expanded in search path")
    check(full.resolvedAccent() == RGBAColor(string: "#BF5AF2"), "named accent resolves to hex")

    // Out-of-range transparency is clamped.
    check(Config.load(from: write("{\"transparency\":5}")).transparency == 1.0, "transparency clamped to 1")
    check(Config.load(from: write("{\"transparency\":-2}")).transparency == 0.0, "transparency clamped to 0")

    // Merge with defaults, de-duplicated.
    let merged = AppIndex.searchPaths(config: Config(searchPaths: ["/Applications", "/tmp/zap-extra"]))
    check(merged.contains { $0.path == "/tmp/zap-extra" }, "config path added to search paths")
    check(merged.filter { $0.path == "/Applications" }.count == 1, "duplicate default path de-duplicated")
}

func testDynamicPaths() {
    print("DynamicPaths")
    let fm = FileManager.default
    let dir = fm.temporaryDirectory.appendingPathComponent("zap-dyn-\(UUID().uuidString)")
    defer { try? fm.removeItem(at: dir) }
    // Nested, so `update` has to create the directory.
    let store = dir.appendingPathComponent("nested/dynamic-paths.json")
    let me = ProcessInfo.processInfo.processIdentifier
    let alive: (Int32) -> Bool = { $0 == 100 }

    check(DynamicPaths.load(from: store).entries.isEmpty, "missing file yields empty store")
    check(DynamicPaths.normalize("  ") == nil, "blank path rejected")
    check(DynamicPaths.normalize("apps/../bin", cwd: "/opt/env") == "/opt/env/bin",
          "relative path resolved against cwd and standardized")
    check(DynamicPaths.normalize("~/x") == fm.homeDirectoryForCurrentUser.path + "/x",
          "tilde expanded")
    check(DynamicPaths.processIsAlive(me), "own process is alive")

    let paths = DynamicPaths()
        .adding("/a").adding("/a")
        .adding("/b", pid: 100).adding("/b", pid: 200)
        .adding("/c", pid: 200)
    check(paths.entries.count == 4, "adding the same entry twice is a no-op")
    check(paths.resolvedPaths(isAlive: alive).map(\.path) == ["/a", "/b"],
          "entries of dead processes are ignored, live ones de-duplicated")
    check(paths.removing("/b", pid: 100).resolvedPaths(isAlive: alive).map(\.path) == ["/a"],
          "remove with pid drops only that owner")
    check(paths.removing("/b", pid: 100).entries.count == 3, "other owner's entry is kept")
    check(!paths.removing("/b").entries.contains { $0.path == "/b" },
          "remove without pid drops every owner")
    check(paths.removing("/a", pid: 100) == paths, "remove with pid leaves unowned entry alone")

    let merged = AppIndex.searchPaths(config: Config(), dynamic: paths.removing("/c"))
    check(merged.contains { $0.path == "/a" }, "dynamic path added to search paths")

    // The command line, end to end against a temp store.
    check(CLI.isGUIInvocation([]), "no arguments starts the app")
    check(CLI.isGUIInvocation(["-psn_0_123"]), "macOS launch flags start the app")
    check(!CLI.isGUIInvocation(["add", "/x"]), "a command does not start the app")
    check((try? CLI.parse(["add", "/x", "--pid", "42"])) == .add(path: "/x", pid: 42),
          "parses add with pid")
    check((try? CLI.parse(["remove", "--pid", "42", "/x"])) == .remove(path: "/x", pid: 42),
          "pid may come before the path")
    check((try? CLI.parse(["add"])) == nil, "add without a directory is an error")
    check((try? CLI.parse(["add", "/x", "--pid", "abc"])) == nil, "non-numeric pid is an error")
    check(CLI.run(["bogus"], store: store).status == 2, "unknown command exits 2")

    check(CLI.run(["add", "/x"], store: store).status == 0, "add succeeds and creates the directory")
    check(CLI.run(["add", "/y", "--pid", "\(me)"], store: store).status == 0, "add with live pid succeeds")
    check(CLI.run(["list"], store: store).output == "/x\n/y", "list prints live paths")
    check(CLI.run(["remove", "/x"], store: store).status == 0, "remove succeeds")
    check(CLI.run(["list"], store: store).output == "/y", "removed path is gone")

    // A dead owner: not listed, and pruned from the file by the next write.
    try? DynamicPaths.update(at: store, isAlive: { _ in true }) { $0.adding("/dead", pid: 100) }
    try? DynamicPaths.update(at: store, isAlive: alive) { $0 }
    check(DynamicPaths.load(from: store).entries == [.init(path: "/dead", pid: 100)],
          "update prunes entries whose process is gone")
}

/// End to end with a real process: a folder added for a process is scanned while the
/// process runs and dropped once it exits, with no `zap remove`.
func testDynamicPathsFollowProcess() {
    print("DynamicPaths (real process)")
    let fm = FileManager.default
    let dir = fm.temporaryDirectory.appendingPathComponent("zap-proc-\(UUID().uuidString)")
    defer { try? fm.removeItem(at: dir) }
    let apps = dir.appendingPathComponent("env/Applications")
    try? fm.createDirectory(at: apps.appendingPathComponent("EnvTool.app"),
                            withIntermediateDirectories: true)
    let store = dir.appendingPathComponent("dynamic-paths.json")

    func visibleApps() -> [String] {
        let paths = AppIndex.searchPaths(config: Config(), dynamic: .load(from: store))
        return AppIndex.scan(paths: paths).map(\.name)
    }

    let shell = Process()
    shell.executableURL = URL(fileURLWithPath: "/bin/sleep")
    shell.arguments = ["60"]
    guard (try? shell.run()) != nil else { check(false, "could not start helper process"); return }

    check(!visibleApps().contains("EnvTool"), "app is not visible before zap add")
    let added = CLI.run(["add", apps.path, "--pid", "\(shell.processIdentifier)"], store: store)
    check(added.status == 0, "zap add --pid succeeds")
    check(visibleApps().contains("EnvTool"), "app is visible while the owning process runs")

    shell.terminate()
    shell.waitUntilExit()
    check(!visibleApps().contains("EnvTool"), "app disappears once the owning process exits")
}

func testAppearance() {
    print("Appearance")
    check(RGBAColor(string: "#ffffff") == RGBAColor(r: 1, g: 1, b: 1), "parses 6-digit hex")
    check(RGBAColor(string: "000") == RGBAColor(r: 0, g: 0, b: 0), "parses 3-digit hex without #")
    check(RGBAColor(string: "#ff000080")?.a == Double(128) / 255.0, "parses 8-digit hex alpha")
    check(RGBAColor(string: "blue") != nil, "named color resolves")
    check(RGBAColor(string: "not-a-color") == nil, "invalid color is nil")
    check(Density.compact.metrics.cardWidth < Density.comfortable.metrics.cardWidth,
          "compact is narrower than comfortable")
    check(Density.simple.metrics.listHeight > Density.compact.metrics.listHeight,
          "simple list taller than compact")
}

func testHotKeySpec() {
    print("HotKeySpec")
    let cmdSpace = HotKeySpec(string: "cmd+space")
    check(cmdSpace?.keyCode == 49, "space key code is 49")
    check(cmdSpace?.modifiers == HotKeySpec.cmd, "cmd modifier mask")
    check(cmdSpace?.display == "⌘Space", "cmd+space display")

    check(HotKeySpec(string: "opt+space")?.modifiers == HotKeySpec.option, "opt modifier mask")

    let combo = HotKeySpec(string: "ctrl+shift+k")
    check(combo?.modifiers == (HotKeySpec.control | HotKeySpec.shift), "combined modifier mask")
    check(combo?.keyCode == 40, "k key code")
    check(combo?.display == "⌃⇧K", "combo display normalized")

    // Modifier order doesn't matter.
    check(HotKeySpec(string: "shift+cmd+a") == HotKeySpec(string: "cmd+shift+a"), "modifier order agnostic")

    // Invalid inputs.
    check(HotKeySpec(string: "cmd+space+return") == nil, "two keys is invalid")
    check(HotKeySpec(string: "cmd+nope") == nil, "unknown key is invalid")
    check(HotKeySpec(string: "cmd") == nil, "modifier only is invalid")
    check(HotKeySpec(string: "") == nil, "empty is invalid")

    // Config default + fallback.
    check(Config().resolvedHotKeys().map(\.display) == ["⌥Space", "⌘Space"], "default hotkeys")
    check(Config(hotkeys: ["garbage"]).resolvedHotKeys().map(\.display) == ["⌥Space", "⌘Space"],
          "all-invalid hotkeys fall back to defaults")
    check(Config(hotkeys: ["ctrl+space"]).resolvedHotKeys().map(\.display) == ["⌃Space"],
          "valid custom hotkey used")
}

func testFrecency() {
    print("Frecency")
    let fm = FileManager.default
    let dir = fm.temporaryDirectory.appendingPathComponent("zap-frecency-\(UUID().uuidString)")
    try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: dir) }
    let url = dir.appendingPathComponent("frecency.json")

    let empty = FrecencyStore.load(from: url)
    check(empty.score("Safari") == 0, "unknown app scores zero")

    let now = Date()
    let once = empty.recordLaunch("Safari", now: now)
    check(once.score("Safari", now: now) == 1, "one launch scores 1 at zero age")

    let twice = once.recordLaunch("Safari", now: now)
    check(twice.score("Safari", now: now) == 2, "two launches score 2 at zero age")

    let decayed = once.score("Safari", now: now.addingTimeInterval(14 * 86400))
    check(abs(decayed - 0.5) < 0.001, "score halves after one half-life")

    once.save(to: url)
    let reloaded = FrecencyStore.load(from: url)
    check(reloaded.score("Safari", now: now) == 1, "round-trips through disk")

    check(FrecencyStore.load(from: dir.appendingPathComponent("nope.json")).entries.isEmpty,
          "missing file yields empty store")
}

testFuzzyMatcher()
testAppIndex()
testConfig()
testDynamicPaths()
testDynamicPathsFollowProcess()
testAppearance()
testHotKeySpec()
testFrecency()

print("")
if failures == 0 {
    print("All checks passed.")
    exit(0)
} else {
    print("\(failures) check(s) FAILED.")
    exit(1)
}
