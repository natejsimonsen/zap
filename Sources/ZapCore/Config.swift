import Foundation

/// User configuration, loaded from `~/.config/zap/config.json`.
///
/// The file is optional. Missing keys fall back to defaults, and a missing or
/// malformed file yields an all-default config (no crash), so Zap always runs.
///
/// ```json
/// {
///   "searchPaths": ["~/Developer/Apps", "/opt/homebrew/Caskroom"],
///   "accentColor": "#BF5AF2",
///   "transparency": 0.8,
///   "density": "comfortable"
/// }
/// ```
public struct Config: Equatable {
    /// Extra directories to search for `.app` bundles, added to the defaults.
    public var searchPaths: [String]
    /// Selection-highlight colour: a hex string (`#RGB`, `#RRGGBB`, `#RRGGBBAA`) or a
    /// palette name (blue, purple, pink, red, orange, yellow, green, teal, graphite).
    /// `nil` uses the system accent colour.
    public var accentColor: String?
    /// Background translucency, 0 (opaque) … 1 (maximum blur / most see-through).
    public var transparency: Double
    /// Layout density.
    public var density: Density

    public init(
        searchPaths: [String] = [],
        accentColor: String? = nil,
        transparency: Double = 0.8,
        density: Density = .comfortable
    ) {
        self.searchPaths = searchPaths
        self.accentColor = accentColor
        self.transparency = transparency.clamped(to: 0...1)
        self.density = density
    }

    /// The default config location: `~/.config/zap/config.json`.
    public static func defaultURL(
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        home.appendingPathComponent(".config/zap/config.json")
    }

    /// Load config from `url`, returning an all-default config if missing or invalid.
    public static func load(from url: URL = Config.defaultURL()) -> Config {
        guard let data = try? Data(contentsOf: url) else { return Config() }
        return (try? JSONDecoder().decode(Config.self, from: data)) ?? Config()
    }

    /// `searchPaths` as resolved file URLs, with `~` expanded and blanks dropped.
    public func resolvedSearchPaths() -> [URL] {
        searchPaths.compactMap { raw in
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return nil }
            return URL(fileURLWithPath: (trimmed as NSString).expandingTildeInPath)
        }
    }

    /// The configured accent colour, if any and parseable.
    public func resolvedAccent() -> RGBAColor? {
        accentColor.flatMap(RGBAColor.init(string:))
    }
}

extension Config: Decodable {
    private enum CodingKeys: String, CodingKey {
        case searchPaths, accentColor, transparency, density
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let paths = try c.decodeIfPresent([String].self, forKey: .searchPaths) ?? []
        let accent = try c.decodeIfPresent(String.self, forKey: .accentColor)
        let transp = try c.decodeIfPresent(Double.self, forKey: .transparency) ?? 0.8
        let density = try c.decodeIfPresent(Density.self, forKey: .density) ?? .comfortable
        self.init(searchPaths: paths, accentColor: accent, transparency: transp, density: density)
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
