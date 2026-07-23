import AppKit

// `NSApplication.run()` blocks until quit, so the local `delegate` stays retained
// for the process lifetime (NSApplication.delegate is a weak reference).
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
