import NoMansTerrainCore
//
//  Nah_Bruh_s_TerrainApp.swift
//  Nah Bruh's Terrain
//
//  Created by Jonathan Gilbert on 6/15/26.
//

import SwiftUI
import SwiftData

@main
struct NoMansTerrainApp: App {
    let modelContainer: ModelContainer

    init() {
        modelContainer = Self.makeContainer()
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(modelContainer)
        .defaultSize(width: 1200, height: 800)
        #if os(macOS)
        .windowResizability(.contentMinSize)
        #endif
    }

    private static func makeContainer() -> ModelContainer {
        let schema = Schema([TerrainSetting.self, TerrainSettingsFolder.self, TerrainSlot.self])
        let configuration = ModelConfiguration(schema: schema)

        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            // The store on disk doesn't match the current schema (a pre-release schema we
            // don't migrate). Discard it and start fresh rather than crashing on launch.
            print("ModelContainer load failed (\(error)); wiping store and recreating.")
            wipeStore(at: configuration.url)
            do {
                return try ModelContainer(for: schema, configurations: configuration)
            } catch {
                fatalError("Failed to create ModelContainer after wiping the store: \(error)")
            }
        }
    }

    private static func wipeStore(at url: URL) {
        let fileManager = FileManager.default
        // SQLite keeps sidecar files alongside the main store.
        for path in [url.path, url.path + "-shm", url.path + "-wal"] {
            try? fileManager.removeItem(atPath: path)
        }
    }
}
