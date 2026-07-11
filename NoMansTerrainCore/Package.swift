// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "NoMansTerrainCore",
    platforms: [.macOS(.v15)],
    products: [
        .library(
            name: "NoMansTerrainCore",
            targets: ["NoMansTerrainCore"]
        ),
    ],
    dependencies: [.package(url: "https://github.com/gistya/hastings", from: "0.8.0")],
    targets: [
        .target(
            name: "NoMansTerrainCore",
            dependencies: [.product(name: "Hastings", package: "hastings")]
        ),
        .testTarget(
            name: "NoMansTerrainCoreTests",
            dependencies: ["NoMansTerrainCore"]
        ),
    ],
    // Match the app target's language mode so moving files in introduces no new
    // (Swift 6 strict-concurrency) compile differences.
    swiftLanguageModes: [.v5]
)
