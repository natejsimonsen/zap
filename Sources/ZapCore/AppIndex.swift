import Foundation

/// A launchable application: its display name and bundle location.
public struct AppEntry: Equatable, Identifiable, Sendable {
    public let name: String
    public let url: URL
    public var id: URL { url }

    public init(name: String, url: URL) {
        self.name = name
        self.url = url
    }
}

/// Scans standard application directories for `.app` bundles.
public enum AppIndex {
    /// The directories a normal user expects GUI apps to live in.
    public static func defaultSearchPaths() -> [URL] {
        let fm = FileManager.default
        return [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications"),
        ]
    }

    /// Scan the given paths, returning a de-duplicated, name-sorted list of apps.
    public static func scan(paths: [URL], fileManager: FileManager = .default) -> [AppEntry] {
        var seen = Set<String>()
        var results: [AppEntry] = []
        for base in paths {
            for bundle in appBundles(in: base, fileManager: fileManager, depth: 2) {
                let key = bundle.standardizedFileURL.path
                guard seen.insert(key).inserted else { continue }
                results.append(AppEntry(name: displayName(for: bundle), url: bundle))
            }
        }
        return results.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    /// Find `.app` bundles under `base`, descending `depth` levels into plain
    /// subdirectories (e.g. `/Applications/Utilities`) but never into a bundle itself.
    private static func appBundles(in base: URL, fileManager fm: FileManager, depth: Int) -> [URL] {
        // Don't skip hidden files: some system apps (e.g. Safari) are hidden
        // symlinks into /System/Cryptexes. Skip dotfiles manually instead.
        guard let entries = try? fm.contentsOfDirectory(
            at: base, includingPropertiesForKeys: [.isDirectoryKey],
            options: []) else { return [] }

        var found: [URL] = []
        for entry in entries {
            if entry.lastPathComponent.hasPrefix(".") { continue }
            let isDir = (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if entry.pathExtension == "app" {
                found.append(entry)
            } else if isDir && depth > 1 {
                found.append(contentsOf: appBundles(in: entry, fileManager: fm, depth: depth - 1))
            }
        }
        return found
    }

    /// Prefer the bundle's declared name, falling back to the file name.
    private static func displayName(for bundle: URL) -> String {
        let plist = bundle.appendingPathComponent("Contents/Info.plist")
        if let data = try? Data(contentsOf: plist),
           let info = try? PropertyListSerialization.propertyList(
               from: data, options: [], format: nil) as? [String: Any] {
            if let display = info["CFBundleDisplayName"] as? String, !display.isEmpty {
                return display
            }
            if let name = info["CFBundleName"] as? String, !name.isEmpty {
                return name
            }
        }
        return bundle.deletingPathExtension().lastPathComponent
    }
}
