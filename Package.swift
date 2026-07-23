// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Zap",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "ZapCore"),
        .executableTarget(
            name: "Zap",
            dependencies: ["ZapCore"]
        ),
        // Self-contained check runner: `swift run ZapCoreTests`.
        // (The Command Line Tools toolchain ships no XCTest/Testing swiftmodule,
        // so a plain executable is what actually runs in this environment.)
        .executableTarget(
            name: "ZapCoreTests",
            dependencies: ["ZapCore"]
        ),
    ]
)
