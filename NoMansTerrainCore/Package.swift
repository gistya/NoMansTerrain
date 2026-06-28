// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "NoMansTerrainCore",
    products: [
        .library(
            name: "NoMansTerrainCore",
            targets: ["NoMansTerrainCore"]
        ),
    ],
    dependencies: [.package(path: "../hastings")],
    targets: [
        .target(
            name: "NoMansTerrainCore",
            dependencies: ["hastings"],
        ),
        .testTarget(
            name: "NoMansTerrainCoreTests",
            dependencies: ["NoMansTerrainCore"]
        ),
    ]
)
