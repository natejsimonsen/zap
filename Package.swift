// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Zap",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "ZapCore"),
        .executableTarget(
            name: "Zap",
            dependencies: ["ZapCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // Self-contained check runner: `swift run ZapCoreTests`.
        // (The Command Line Tools toolchain ships no XCTest/Testing swiftmodule,
        // so a plain executable is what actually runs in this environment.)
        .executableTarget(
            name: "ZapCoreTests",
            dependencies: ["ZapCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
