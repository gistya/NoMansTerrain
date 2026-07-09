// swift-tools-version: 6.2

import PackageDescription

// Pure-Swift, cross-platform (macOS / Windows / Linux) spike for NoMansTerrain.
// UI: SwiftCrossUI (DefaultBackend picks AppKit on macOS, WinUI on Windows, Gtk on Linux).
// Logic/rendering: the shared NoMansTerrainCore package — no SwiftUI/SwiftData.
let package = Package(
    name: "NoMansTerrainCrossUI",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/stackotter/swift-cross-ui", from: "0.7.0"),
        .package(url: "https://github.com/stackotter/swift-image-formats", .upToNextMinor(from: "0.5.0")),
        .package(path: "../NoMansTerrainCore"),
    ],
    targets: [
        .executableTarget(
            name: "NoMansTerrainCrossUI",
            dependencies: [
                .product(name: "SwiftCrossUI", package: "swift-cross-ui"),
                .product(name: "DefaultBackend", package: "swift-cross-ui"),
                // For the native macOS histogram (NSViewRepresentable). The Windows
                // equivalent (WinUIBackend → WinUIElementRepresentable) gets added when the
                // native Win2D histogram is built on a Windows machine.
                .product(name: "AppKitBackend", package: "swift-cross-ui", condition: .when(platforms: [.macOS])),
                .product(name: "ImageFormats", package: "swift-image-formats"),
                .product(name: "NoMansTerrainCore", package: "NoMansTerrainCore"),
            ],
            resources: [
                .process("Resources"), // base.json: the aggregated base terrain (min/max)
            ]
        )
    ]
)
