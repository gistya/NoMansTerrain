//
//  Nah_Bruh_s_TerrainTests.swift
//  Nah Bruh's TerrainTests
//
//  Created by Jonathan Gilbert on 6/15/26.
//

import Foundation
import SwiftUI
import SwiftData
import Testing
@testable import NoMansTerrain

struct NoMansTerrainTests {
    private var terrainDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("nms_terrain", isDirectory: true)
    }

    @Test
    func loadsAndAggregatesProductionTerrainLimits() async throws {
//        let minURLs = try FileManager.default.contentsOfDirectory(
//            at: terrainDirectory.appendingPathComponent("Min"),
//            includingPropertiesForKeys: nil
//        ).filter { $0.pathExtension == "xml" }
//
//        let maxURLs = try FileManager.default.contentsOfDirectory(
//            at: terrainDirectory.appendingPathComponent("Max"),
//            includingPropertiesForKeys: nil
//        ).filter { $0.pathExtension == "xml" }

        let fileLoader = FileLoader()
        let availablePresets = try await fileLoader.availablePresets()
        let settings = try await fileLoader.makeModelsOfXML()
        let aggregate = try settings.aggregate()

        #expect(!availablePresets.isEmpty)
        #expect(settings.count == availablePresets.count, "Loaded \(settings.count) of \(availablePresets.count) matched terrain pairs")

        let aggregatedMin = aggregate.min
        let aggregatedMax = aggregate.max

        #expect(aggregatedMin.seaLevel <= aggregatedMax.seaLevel)
        #expect(aggregatedMin.beachHeight <= aggregatedMax.beachHeight)
        #expect(aggregatedMin.noiseLayers.base.height <= aggregatedMax.noiseLayers.base.height)

        let outputDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("terrain-limits-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let minURL = try await fileLoader.write(terrain: .alien(.standard, .min), data: aggregatedMin, to: outputDirectory)
        let maxURL = try await fileLoader.write(terrain: .alien(.standard, .max), data: aggregatedMax, to: outputDirectory)

        #expect(FileManager.default.fileExists(atPath: minURL.path))
        #expect(FileManager.default.fileExists(atPath: maxURL.path))

        let minXML = try String(contentsOf: minURL, encoding: .utf8)
        let maxXML = try String(contentsOf: maxURL, encoding: .utf8)
        #expect(minXML.contains("Property name=\"Min\""))
        #expect(maxXML.contains("Property name=\"Max\""))
    }

    @Test
    func exportServiceWritesXMLFilePair() async throws {
        let fileLoader = FileLoader()
        let preset = try #require(try await fileLoader.availablePresets().first)
        let pair = try await fileLoader.loadTerrainPair(preset: preset)

        let urls = try await TerrainExportService.writeXMLPairToTemporaryDirectory(
            preset: preset,
            minData: pair.min,
            maxData: pair.max
        )

        #expect(urls.count == 2)
        for url in urls {
            #expect(url.pathExtension == "xml", "Exported file should be .xml: \(url.lastPathComponent)")
            #expect(FileManager.default.fileExists(atPath: url.path), "Missing exported file: \(url.path)")
            let contents = try String(contentsOf: url, encoding: .utf8)
            #expect(contents.contains("TkVoxelGeneratorData"))
        }
    }

    @Test @MainActor
    func savesAndReloadsTerrainSettingViaSwiftData() async throws {
        let fileLoader = FileLoader()
        let preset = try #require(try await fileLoader.availablePresets().first)
        let pair = try await fileLoader.loadTerrainPair(preset: preset)

        // Use an on-disk store: the SQLite "too many columns" schema failure only
        // surfaces when the store is actually created on disk, not in-memory.
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("terrain-store-\(UUID().uuidString).store")
        let container = try ModelContainer(
            for: TerrainSetting.self,
            configurations: ModelConfiguration(url: storeURL)
        )
        let context = container.mainContext

        let setting = TerrainSetting(
            name: "Round Trip",
            preset: preset,
            min: TerrainMin(min: pair.min),
            max: TerrainMax(max: pair.max)
        )
        context.insert(setting)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<TerrainSetting>())
        #expect(fetched.count == 1)
        let loaded = try #require(fetched.first)
        #expect(loaded.name == "Round Trip")
        #expect(loaded.preset == preset)
        #expect(loaded.sendableMin.seaLevel == pair.min.seaLevel)
        #expect(loaded.sendableMax.noiseLayers.base.height == pair.max.noiseLayers.base.height)
    }

    @Test @MainActor
    func generateRandomBatchWritesPairForEveryPreset() async throws {
        let fileLoader = FileLoader()
        let aggregate = try await fileLoader.makeModelsOfXML().aggregate()

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("random-batch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let written = try await TerrainRandomBatch.generateAll(
            into: directory,
            globalMin: aggregate.min,
            globalMax: aggregate.max
        ) { _, _ in }

        #expect(written == TerrainPreset.all.count)

        func xmlCount(in subfolder: String) throws -> Int {
            try FileManager.default
                .contentsOfDirectory(at: directory.appendingPathComponent(subfolder), includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "xml" }
                .count
        }

        #expect(try xmlCount(in: "Min") == TerrainPreset.all.count)
        #expect(try xmlCount(in: "Max") == TerrainPreset.all.count)
    }

    @Test @MainActor
    func activateAllTurnsOnEveryActiveToggle() async throws {
        let fileLoader = FileLoader()
        let preset = try #require(try await fileLoader.availablePresets().first)
        let pair = try await fileLoader.loadTerrainPair(preset: preset)

        var data = pair.min
        TerrainEditorOperations.activateAll(&data)

        #expect(data.noiseLayers.base.active)
        #expect(data.noiseLayers.continent.active)
        #expect(data.gridLayers.small.active)
        #expect(data.gridLayers.resourcesEmeril.active)
        #expect(data.gridLayers.large.turbulenceNoiseLayer.active)
        #expect(data.features.river.active)
        #expect(data.features.substance.active)
        #expect(data.caves.underground.mouth.active)
        #expect(data.caves.underground.tunnel.active)
    }

    @Test @MainActor
    func terrainEditorSessionNestedBindingsMutateValues() async throws {
        let fileLoader = FileLoader()
        let presets = try await fileLoader.availablePresets()
        let preset = try #require(presets.first)
        let pair = try await fileLoader.loadTerrainPair(preset: preset)
        let session = TerrainEditorSession.fromBundle(preset: preset, pair: pair)

        let originalSeaLevel = session.minData.seaLevel
        session.minDataBinding.nested(\.seaLevel).wrappedValue = originalSeaLevel + 1.25

        #expect(session.minData.seaLevel == originalSeaLevel + 1.25)

        mutatePair(session.minDataBinding, session.maxDataBinding) { min, max in
            TerrainEditorOperations.randomizeRootScalars(
                minData: &min,
                maxData: &max,
                refMin: pair.min,
                refMax: pair.max
            )
        }

        #expect(session.minData.seaLevel != originalSeaLevel)
    }
}
