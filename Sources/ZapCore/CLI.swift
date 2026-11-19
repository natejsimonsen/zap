import Foundation

/// The `zap` command line: `zap add|remove|list`. With no arguments the same binary
/// starts the launcher app.
public enum CLI {
    public enum Command: Equatable {
        case add(path: String, pid: Int32?)
        case remove(path: String, pid: Int32?)
        case list
        case help
    }

    public struct UsageError: Error, Equatable {
        public let message: String
    }

    public static let usage = """
    usage: zap                          start the launcher
           zap add <dir> [--pid <pid>]  also search <dir> for apps
           zap remove <dir> [--pid <pid>]
           zap list                     print the directories added with `zap add`

    --pid ties the directory to a process (e.g. --pid $$ for the current shell):
    it is dropped automatically when that process exits.
    """

    /// True when the arguments (without argv[0]) mean "start the app": none at all, or
    /// only the `-psn…` / `-NS…` / `-Apple…` flags macOS itself passes to GUI apps.
    public static func isGUIInvocation(_ args: [String]) -> Bool {
        guard let first = args.first else { return true }
        return ["-psn", "-NS", "-Apple"].contains { first.hasPrefix($0) }
    }

    public static func parse(_ args: [String]) throws -> Command {
        guard let verb = args.first else { return .help }
        switch verb {
        case "help", "--help", "-h":
            return .help
        case "list":
            guard args.count == 1 else { throw UsageError(message: "list takes no arguments") }
            return .list
        case "add", "remove":
            var path: String?
            var pid: Int32?
            var rest = args.dropFirst()
            while let arg = rest.popFirst() {
                if arg == "--pid" {
                    guard let value = rest.popFirst(), let parsed = Int32(value), parsed > 0 else {
                        throw UsageError(message: "--pid needs a process id")
                    }
                    pid = parsed
                } else if path == nil {
                    path = arg
                } else {
                    throw UsageError(message: "unexpected argument: \(arg)")
                }
            }
            guard let raw = path, let normalized = DynamicPaths.normalize(raw) else {
                throw UsageError(message: "\(verb) needs a directory")
            }
            return verb == "add" ? .add(path: normalized, pid: pid)
                                 : .remove(path: normalized, pid: pid)
        default:
            throw UsageError(message: "unknown command: \(verb)")
        }
    }

    /// Run a command line. Returns the exit status and any text to print
    /// (to stdout on success, stderr on failure).
    public static func run(
        _ args: [String], store: URL = DynamicPaths.defaultURL()
    ) -> (status: Int32, output: String) {
        do {
            switch try parse(args) {
            case .help:
                return (0, usage)
            case .list:
                let paths = DynamicPaths.load(from: store).resolvedPaths().map(\.path)
                return (0, paths.joined(separator: "\n"))
            case let .add(path, pid):
                try DynamicPaths.update(at: store) { $0.adding(path, pid: pid) }
                return (0, "")
            case let .remove(path, pid):
                try DynamicPaths.update(at: store) { $0.removing(path, pid: pid) }
                return (0, "")
            }
        } catch let error as UsageError {
            return (2, "zap: \(error.message)\n\(usage)")
        } catch {
            return (1, "zap: \(error.localizedDescription)")
        }
    }
}
