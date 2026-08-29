import AppKit
import Combine
import ZapCore

/// Observable state backing the search UI: the query, the ranked matches, and the
/// current keyboard selection. Owns the launch action.
@MainActor
final class LauncherModel: ObservableObject {
    @Published var query = "" {
        didSet {
            // "?" toggles the shortcuts overlay and clears itself, so no app is ever
            // searched for the literal character.
            if query == "?" {
                showHelp.toggle()
                query = ""
                return
            }
            if !query.isEmpty { showHelp = false }
            recompute()
        }
    }
    @Published private(set) var results: [AppEntry] = []
    @Published var selection = 0
    @Published private(set) var showHelp = false
    /// Current user configuration, refreshed on each open.
    @Published private(set) var config = Config()

    /// Invoked to dismiss the panel (set by the panel controller).
    var onClose: (() -> Void)?

    private var all: [AppEntry] = []
    private var iconCache: [URL: NSImage] = [:]
    private var frecency = FrecencyStore()
    /// How heavily launch history can outweigh a plain fuzzy-match score. Tuned so a
    /// heavily-used app can overtake a merely-prefix match, but not a fresh exact match.
    private let frecencyWeight = 3.0

    /// Re-scan the disk. Cheap enough to run every time the panel opens.
    /// Also reloads config so edits take effect on the next open.
    func reload() {
        config = Config.load()
        frecency = FrecencyStore.load()
        all = AppIndex.scan(paths: AppIndex.searchPaths(config: config))
        showHelp = false
        recompute()
    }

    private func recompute() {
        let now = Date()
        if query.isEmpty {
            // No query: lead with what you actually use, most frecent first.
            results = all.sorted { lhs, rhs in
                let l = frecency.score(key(for: lhs), now: now)
                let r = frecency.score(key(for: rhs), now: now)
                return l != r
                    ? l > r
                    : lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        } else {
            results = all
                .compactMap { app -> (AppEntry, Double)? in
                    guard let score = FuzzyMatcher.score(query: query, in: app.name) else { return nil }
                    let boost = frecency.score(key(for: app), now: now) * frecencyWeight
                    return (app, Double(score) + boost)
                }
                .sorted { lhs, rhs in
                    lhs.1 != rhs.1
                        ? lhs.1 > rhs.1
                        : lhs.0.name.localizedCaseInsensitiveCompare(rhs.0.name) == .orderedAscending
                }
                .map(\.0)
        }
        selection = 0
    }

    private func key(for app: AppEntry) -> String { app.url.standardizedFileURL.path }

    func moveUp() {
        guard !results.isEmpty else { return }
        selection = max(0, selection - 1)
    }

    func moveDown() {
        guard !results.isEmpty else { return }
        selection = min(results.count - 1, selection + 1)
    }

    func cancel() {
        if showHelp {
            showHelp = false
            return
        }
        onClose?()
    }

    /// Launch the selected app, record it for frecency ranking, and dismiss.
    func activate() {
        guard !showHelp, results.indices.contains(selection) else { return }
        let app = results[selection]
        frecency = frecency.recordLaunch(key(for: app))
        frecency.save()
        onClose?()
        NSWorkspace.shared.open(app.url)
    }

    /// Force-quit the selected app if it's currently running. No-op otherwise —
    /// this is a kill switch, not a launcher, so a non-running app does nothing.
    func forceQuitSelected() {
        guard !showHelp, results.indices.contains(selection) else { return }
        let target = results[selection].url.standardizedFileURL
        let running = NSWorkspace.shared.runningApplications.filter {
            $0.bundleURL?.standardizedFileURL == target
        }
        for app in running {
            app.forceTerminate()
        }
    }

    /// A cached icon for the app bundle.
    func icon(for app: AppEntry) -> NSImage {
        if let cached = iconCache[app.url] { return cached }
        let image = NSWorkspace.shared.icon(forFile: app.url.path)
        image.size = NSSize(width: 64, height: 64)
        iconCache[app.url] = image
        return image
    }
}
