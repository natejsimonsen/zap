import Foundation

/// Tracks how often and how recently each app has been launched, so search results
/// can be biased toward the apps you actually use ("frecency" = frequency + recency),
/// persisted to `~/.config/zap/frecency.json`.
public struct FrecencyStore: Equatable {
    public struct Entry: Equatable, Codable {
        public var count: Int
        public var lastLaunch: Date
    }

    public private(set) var entries: [String: Entry]

    public init(entries: [String: Entry] = [:]) {
        self.entries = entries
    }

    /// The default persistence location: `~/.config/zap/frecency.json`.
    public static func defaultURL(
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        home.appendingPathComponent(".config/zap/frecency.json")
    }

    /// Load from `url`, returning an empty store if missing or malformed (no crash).
    public static func load(from url: URL = FrecencyStore.defaultURL()) -> FrecencyStore {
        guard let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([String: Entry].self, from: data)
        else { return FrecencyStore() }
        return FrecencyStore(entries: entries)
    }

    /// Persist to `url`, creating the parent directory if needed. Fails silently.
    public func save(to url: URL = FrecencyStore.defaultURL()) {
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: url)
    }

    /// Record a launch of `key` right now, returning the updated store.
    public func recordLaunch(_ key: String, now: Date = Date()) -> FrecencyStore {
        var copy = self
        var entry = copy.entries[key] ?? Entry(count: 0, lastLaunch: now)
        entry.count += 1
        entry.lastLaunch = now
        copy.entries[key] = entry
        return copy
    }

    /// Frequency weighted by recency: each launch's contribution halves every
    /// `halfLifeDays`, so an app you've stopped using drops back down over time.
    public func score(_ key: String, now: Date = Date()) -> Double {
        guard let entry = entries[key] else { return 0 }
        let halfLifeDays = 14.0
        let ageDays = now.timeIntervalSince(entry.lastLaunch) / 86400
        let decay = pow(0.5, ageDays / halfLifeDays)
        return Double(entry.count) * decay
    }
}
