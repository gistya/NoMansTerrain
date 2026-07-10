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
            ],
            linkerSettings: [
                // SwiftCrossUI's view-layout recursion is extremely stack-heavy: each view
                // `body`/layout frame materializes its whole (wide) TupleView of child-view
                // structs by value, so single frames consume tens of KB. Windows links
                // executables with only a 1 MB main-thread stack reserve by default (macOS
                // gives the main thread 8 MB), which this app's dense Min/Max editor views
                // overflow → STACK_OVERFLOW (0xC00000FD) in swift_getTypeByMangledName on
                // launch. Reserve 64 MB on Windows; it's lazily committed virtual address
                // space (no physical cost until touched) and leaves ample headroom.
                .unsafeFlags(["-Xlinker", "/STACK:67108864"], .when(platforms: [.windows])),
            ]
        )
    ]
)
