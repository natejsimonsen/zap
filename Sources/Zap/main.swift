import AppKit
import ZapCore

// `zap add|remove|list` runs as a plain command; no arguments starts the app.
let arguments = Array(CommandLine.arguments.dropFirst())
if !CLI.isGUIInvocation(arguments) {
    let result = CLI.run(arguments)
    if !result.output.isEmpty {
        let stream = result.status == 0 ? FileHandle.standardOutput : FileHandle.standardError
        stream.write(Data((result.output + "\n").utf8))
    }
    exit(result.status)
}

// `NSApplication.run()` blocks until quit, so the local `delegate` stays retained
// for the process lifetime (NSApplication.delegate is a weak reference).
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
