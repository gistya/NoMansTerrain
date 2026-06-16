//
//  Nah_Bruh_s_TerrainTests.swift
//  Nah Bruh's TerrainTests
//
//  Created by Jonathan Gilbert on 6/15/26.
//

import Foundation
import Testing
@testable import Nah_Bruh_s_Terrain

struct Nah_Bruh_s_TerrainTests {
    private var terrainDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("nms_terrain", isDirectory: true)
    }

    @Test func loadsAndAggregatesProductionTerrainLimits() throws {
        let minURLs = try FileManager.default.contentsOfDirectory(
            at: terrainDirectory.appendingPathComponent("Min"),
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "xml" }

        let maxURLs = try FileManager.default.contentsOfDirectory(
            at: terrainDirectory.appendingPathComponent("Max"),
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "xml" }

        let merger = TerrainLimitsMerger(minURLs: minURLs, maxURLs: maxURLs)

        #expect(merger.mins.count >= 20, "Loaded \(merger.mins.count) min files; skipped: \(merger.skippedFiles)")
        #expect(merger.maxs.count >= 20, "Loaded \(merger.maxs.count) max files; skipped: \(merger.skippedFiles)")
        #expect(merger.aggregatedMin != nil)
        #expect(merger.aggregatedMax != nil)

        let aggregatedMin = try #require(merger.aggregatedMin)
        let aggregatedMax = try #require(merger.aggregatedMax)

        #expect(aggregatedMin.seaLevel <= aggregatedMax.seaLevel)
        #expect(aggregatedMin.beachHeight <= aggregatedMax.beachHeight)
        #expect(aggregatedMin.noiseLayers.base.height <= aggregatedMax.noiseLayers.base.height)

        let outputDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("terrain-limits-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let urls = try merger.writeAggregated(to: outputDirectory)
        #expect(FileManager.default.fileExists(atPath: urls.minURL.path))
        #expect(FileManager.default.fileExists(atPath: urls.maxURL.path))

        let minXML = try String(contentsOf: urls.minURL, encoding: .utf8)
        let maxXML = try String(contentsOf: urls.maxURL, encoding: .utf8)
        #expect(minXML.contains("Property name=\"Min\""))
        #expect(maxXML.contains("Property name=\"Max\""))
    }
}