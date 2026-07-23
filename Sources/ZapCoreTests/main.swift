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

testFuzzyMatcher()
testAppIndex()
testConfig()
testAppearance()

print("")
if failures == 0 {
    print("All checks passed.")
    exit(0)
} else {
    print("\(failures) check(s) FAILED.")
    exit(1)
}
