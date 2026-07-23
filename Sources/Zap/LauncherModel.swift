import AppKit
import Combine
import ZapCore

/// Observable state backing the search UI: the query, the ranked matches, and the
/// current keyboard selection. Owns the launch action.
@MainActor
final class LauncherModel: ObservableObject {
    @Published var query = "" { didSet { recompute() } }
    @Published private(set) var results: [AppEntry] = []
    @Published var selection = 0
    /// Current user configuration, refreshed on each open.
    @Published private(set) var config = Config()

    /// Invoked to dismiss the panel (set by the panel controller).
    var onClose: (() -> Void)?

    private var all: [AppEntry] = []
    private var iconCache: [URL: NSImage] = [:]

    /// Re-scan the disk. Cheap enough to run every time the panel opens.
    /// Also reloads config so edits take effect on the next open.
    func reload() {
        config = Config.load()
        all = AppIndex.scan(paths: AppIndex.searchPaths(config: config))
        recompute()
    }

    private func recompute() {
        if query.isEmpty {
            results = all
        } else {
            results = all
                .compactMap { app -> (AppEntry, Int)? in
                    guard let score = FuzzyMatcher.score(query: query, in: app.name) else { return nil }
                    return (app, score)
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

    func moveUp() {
        guard !results.isEmpty else { return }
        selection = max(0, selection - 1)
    }

    func moveDown() {
        guard !results.isEmpty else { return }
        selection = min(results.count - 1, selection + 1)
    }

    func cancel() {
        onClose?()
    }

    /// Launch the selected app and dismiss.
    func activate() {
        guard results.indices.contains(selection) else { return }
        let url = results[selection].url
        onClose?()
        NSWorkspace.shared.open(url)
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
