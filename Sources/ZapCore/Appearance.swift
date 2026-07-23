import Foundation

/// A colour as straight RGBA components in 0...1. UI-framework agnostic so it stays
/// testable in `ZapCore`; the app layer converts it to a SwiftUI `Color`.
public struct RGBAColor: Equatable {
    public let r, g, b, a: Double

    public init(r: Double, g: Double, b: Double, a: Double = 1) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    /// Parse a hex string (`#RGB`, `#RRGGBB`, `#RRGGBBAA`, `#` optional) or a palette name.
    public init?(string raw: String) {
        let s = raw.trimmingCharacters(in: .whitespaces).lowercased()
        if let named = RGBAColor.palette[s] {
            self = named
            return
        }
        guard let hex = RGBAColor.fromHex(s) else { return nil }
        self = hex
    }

    /// Parse a hex colour only (no palette lookup). Used to build the palette itself.
    static func fromHex(_ raw: String) -> RGBAColor? {
        var hex = raw.trimmingCharacters(in: .whitespaces).lowercased()
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard !hex.isEmpty, hex.allSatisfy({ $0.isHexDigit }) else { return nil }

        func component(_ substr: Substring) -> Double? {
            Int(substr, radix: 16).map { Double($0) / 255.0 }
        }

        let chars = Array(hex)
        switch chars.count {
        case 3:
            guard let r = component(Substring(String(repeating: chars[0], count: 2))),
                  let g = component(Substring(String(repeating: chars[1], count: 2))),
                  let b = component(Substring(String(repeating: chars[2], count: 2))) else { return nil }
            return RGBAColor(r: r, g: g, b: b)
        case 6:
            guard let r = component(hex.prefix(2)),
                  let g = component(hex.dropFirst(2).prefix(2)),
                  let b = component(hex.dropFirst(4).prefix(2)) else { return nil }
            return RGBAColor(r: r, g: g, b: b)
        case 8:
            guard let r = component(hex.prefix(2)),
                  let g = component(hex.dropFirst(2).prefix(2)),
                  let b = component(hex.dropFirst(4).prefix(2)),
                  let a = component(hex.dropFirst(6).prefix(2)) else { return nil }
            return RGBAColor(r: r, g: g, b: b, a: a)
        default:
            return nil
        }
    }

    /// Named colours mirroring macOS system accent colours.
    static let palette: [String: RGBAColor] = [
        "blue": RGBAColor.fromHex("0A84FF")!,
        "purple": RGBAColor.fromHex("BF5AF2")!,
        "pink": RGBAColor.fromHex("FF375F")!,
        "red": RGBAColor.fromHex("FF453A")!,
        "orange": RGBAColor.fromHex("FF9F0A")!,
        "yellow": RGBAColor.fromHex("FFD60A")!,
        "green": RGBAColor.fromHex("32D74B")!,
        "teal": RGBAColor.fromHex("64D2FF")!,
        "graphite": RGBAColor.fromHex("8E8E93")!,
    ]
}

/// Layout density presets.
public enum Density: String, Decodable, Equatable {
    case compact
    case simple
    case comfortable

    public var metrics: LayoutMetrics {
        switch self {
        case .comfortable:
            return LayoutMetrics(cardWidth: 640, searchFieldHeight: 68, searchFontSize: 26,
                                 rowFontSize: 16, iconSize: 28, rowVerticalPadding: 8, listHeight: 360)
        case .simple:
            return LayoutMetrics(cardWidth: 600, searchFieldHeight: 58, searchFontSize: 22,
                                 rowFontSize: 15, iconSize: 24, rowVerticalPadding: 6, listHeight: 330)
        case .compact:
            return LayoutMetrics(cardWidth: 560, searchFieldHeight: 46, searchFontSize: 18,
                                 rowFontSize: 13, iconSize: 18, rowVerticalPadding: 3, listHeight: 280)
        }
    }
}

/// Concrete sizes the UI reads for a given density.
public struct LayoutMetrics: Equatable {
    public let cardWidth: Double
    public let searchFieldHeight: Double
    public let searchFontSize: Double
    public let rowFontSize: Double
    public let iconSize: Double
    public let rowVerticalPadding: Double
    public let listHeight: Double
}
