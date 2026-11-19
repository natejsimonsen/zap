import Foundation

/// Search paths added at runtime by the `zap add` / `zap remove` commands, kept in
/// `~/.config/zap/dynamic-paths.json` so the hand-written `config.json` is never rewritten.
///
/// An entry may be tied to a process id (usually a shell). It then counts only while
/// that process is alive, so a path added by an environment's shell disappears when
/// the shell exits, even if nothing calls `zap remove`.
public struct DynamicPaths: Equatable {
    public struct Entry: Equatable, Codable {
        public var path: String
        public var pid: Int32?

        public init(path: String, pid: Int32? = nil) {
            self.path = path
            self.pid = pid
        }
    }

    public private(set) var entries: [Entry]

    public init(entries: [Entry] = []) {
        self.entries = entries
    }

    /// The default location: `~/.config/zap/dynamic-paths.json`.
    public static func defaultURL(
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        home.appendingPathComponent(".config/zap/dynamic-paths.json")
    }

    /// Load from `url`, returning an empty store if missing or malformed (no crash).
    public static func load(from url: URL = DynamicPaths.defaultURL()) -> DynamicPaths {
        guard let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([Entry].self, from: data)
        else { return DynamicPaths() }
        return DynamicPaths(entries: entries)
    }

    /// Whether a process with this id currently exists.
    public static func processIsAlive(_ pid: Int32) -> Bool {
        // Signal 0 only checks existence. EPERM means it exists but isn't ours.
        kill(pid, 0) == 0 || errno == EPERM
    }

    /// An absolute, standardized path: `~` expanded, relative paths resolved against `cwd`.
    /// Returns `nil` for a blank string.
    public static func normalize(
        _ raw: String, cwd: String = FileManager.default.currentDirectoryPath
    ) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let expanded = (trimmed as NSString).expandingTildeInPath
        let url = expanded.hasPrefix("/")
            ? URL(fileURLWithPath: expanded)
            : URL(fileURLWithPath: cwd).appendingPathComponent(expanded)
        return url.standardizedFileURL.path
    }

    /// Entries whose owning process (if any) is still alive.
    public func live(isAlive: (Int32) -> Bool = DynamicPaths.processIsAlive) -> [Entry] {
        entries.filter { $0.pid.map(isAlive) ?? true }
    }

    /// The live paths as file URLs, de-duplicated in order.
    public func resolvedPaths(isAlive: (Int32) -> Bool = DynamicPaths.processIsAlive) -> [URL] {
        var seen = Set<String>()
        return live(isAlive: isAlive).compactMap { entry in
            seen.insert(entry.path).inserted ? URL(fileURLWithPath: entry.path) : nil
        }
    }

    /// Add `path` (already normalized), optionally owned by `pid`. Adding twice is a no-op.
    public func adding(_ path: String, pid: Int32? = nil) -> DynamicPaths {
        let entry = Entry(path: path, pid: pid)
        guard !entries.contains(entry) else { return self }
        return DynamicPaths(entries: entries + [entry])
    }

    /// Remove `path`. With a `pid`, only that owner's entry goes; without, every entry for it.
    public func removing(_ path: String, pid: Int32? = nil) -> DynamicPaths {
        DynamicPaths(entries: entries.filter { entry in
            guard entry.path == path else { return true }
            return pid != nil && entry.pid != pid
        })
    }

    /// Read, change and write the store at `url` under a file lock, so two shells
    /// activating at once don't lose each other's entries. Dead entries are dropped.
    @discardableResult
    public static func update(
        at url: URL = DynamicPaths.defaultURL(),
        isAlive: (Int32) -> Bool = DynamicPaths.processIsAlive,
        _ change: (DynamicPaths) -> DynamicPaths
    ) throws -> DynamicPaths {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

        let lock = open(url.path + ".lock", O_CREAT | O_RDWR, 0o644)
        guard lock >= 0 else { throw CocoaError(.fileWriteUnknown) }
        defer { close(lock) }
        flock(lock, LOCK_EX)

        let current = DynamicPaths(entries: load(from: url).live(isAlive: isAlive))
        let updated = change(current)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(updated.entries).write(to: url, options: .atomic)
        return updated
    }
}
