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

testFuzzyMatcher()
testAppIndex()

print("")
if failures == 0 {
    print("All checks passed.")
    exit(0)
} else {
    print("\(failures) check(s) FAILED.")
    exit(1)
}
