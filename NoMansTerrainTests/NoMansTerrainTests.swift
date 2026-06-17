//
//  Nah_Bruh_s_TerrainTests.swift
//  Nah Bruh's TerrainTests
//
//  Created by Jonathan Gilbert on 6/15/26.
//

import Foundation
import SwiftUI
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
