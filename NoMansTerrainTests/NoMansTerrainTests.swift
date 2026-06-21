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

// Serialized: several tests build SwiftData `ModelContainer`s, which crash when created
// concurrently under Swift Testing's default parallel execution.
@Suite(.serialized)
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

        // The batch also assembles the single combined file at the directory root.
        let combinedURL = directory.appendingPathComponent(TerrainRandomBatch.combinedFileName)
        #expect(FileManager.default.fileExists(atPath: combinedURL.path))
    }

    @Test @MainActor
    func combinedFileAssemblesEveryPresetAndExcludesNonPrimeWaterWorld() async throws {
        let fileLoader = FileLoader()
        let aggregate = try await fileLoader.makeModelsOfXML().aggregate()

        let entries = TerrainPreset.all.map {
            NMSPropertySerializer.CombinedEntry(name: $0.fileBaseName, min: aggregate.min, max: aggregate.max)
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("combined-\(UUID().uuidString).xml")
        try NMSPropertySerializer.writeCombined(entries, to: url)

        let xml = try String(contentsOf: url, encoding: .utf8)
        #expect(xml.hasPrefix("<?xml version=\"1.0\" encoding=\"utf-8\"?>"))
        #expect(xml.contains("template=\"cTkVoxelGeneratorSettingsArray\""))
        #expect(xml.contains("name=\"TerrainSettings\""))

        let elementCount = xml.components(separatedBy: "value=\"TkVoxelGeneratorSettingsElement\"").count - 1
        #expect(elementCount == TerrainPreset.all.count)

        // Waterworld ships only as the Prime variant.
        #expect(xml.contains("name=\"WaterworldPrime\""))
        #expect(!xml.contains("name=\"Waterworld\""))
        #expect(!xml.contains("name=\"WaterworldPurple\""))

        // Hastings produced a well-formed document.
        let parser = Foundation.XMLParser(data: Data(xml.utf8))
        #expect(parser.parse(), "Combined file should be well-formed XML")
    }

    @Test
    func presetListExposesOnlyWaterWorldPrime() {
        let waterWorld = TerrainPreset.all.filter { $0.kind == .waterworld }
        #expect(waterWorld.count == 1)
        #expect(waterWorld.first?.category == .prime)
    }

    // MARK: - Workflow A

    @Test @MainActor
    func safeDefaultsWidenToWidestOfAggregatedAndDocumented() async throws {
        let aggregate = try await FileLoader().makeModelsOfXML().aggregate()

        var minData = aggregate.min
        var maxData = aggregate.max
        TerrainEditorOperations.applySafeDefaults(min: &minData, max: &maxData)

        // Documented field (UberLayer.width = 0...9999): widened to the lower/higher of
        // the aggregated value and the documented bound.
        let docWidth = TerrainFieldDocLimits.UberLayer.width
        #expect(minData.noiseLayers.base.width == Swift.min(aggregate.min.noiseLayers.base.width, docWidth.lowerBound))
        #expect(maxData.noiseLayers.base.width == Swift.max(aggregate.max.noiseLayers.base.width, docWidth.upperBound))
        #expect(minData.noiseLayers.base.width <= maxData.noiseLayers.base.width)

        // Undocumented root scalar is left at the aggregated value.
        #expect(minData.seaLevel == aggregate.min.seaLevel)
        #expect(maxData.seaLevel == aggregate.max.seaLevel)
    }

    @Test
    func absoluteBoundsSnapsDocumentedFieldsToLimits() async throws {
        let aggregate = try await FileLoader().makeModelsOfXML().aggregate()
        var minData = aggregate.min
        var maxData = aggregate.max
        TerrainEditorOperations.applyAbsoluteBounds(min: &minData, max: &maxData)

        let docWidth = TerrainFieldDocLimits.UberLayer.width
        #expect(minData.noiseLayers.base.width == docWidth.lowerBound)
        #expect(maxData.noiseLayers.base.width == docWidth.upperBound)

        let gridYaw = TerrainFieldDocLimits.Grid.yaw
        #expect(minData.gridLayers.small.yaw == gridYaw.lowerBound)
        #expect(maxData.gridLayers.small.yaw == gridYaw.upperBound)

        // Undocumented root scalar is untouched.
        #expect(minData.seaLevel == aggregate.min.seaLevel)
        #expect(maxData.seaLevel == aggregate.max.seaLevel)
    }

    @Test
    func preservingActiveKeepsActiveFlagsButTakesOtherFields() async throws {
        let preset = try #require(try await FileLoader().availablePresets().first)
        let pair = try await FileLoader().loadTerrainPair(preset: preset)

        var previous = pair.min
        previous.gridLayers.small.active = true
        previous.gridLayers.small.turbulenceNoiseLayer.active = false
        previous.noiseLayers.base.active = true
        previous.features.river.active = false
        previous.caves.underground.mouth.active = true

        var updated = pair.max
        updated.gridLayers.small.active = false
        updated.gridLayers.small.turbulenceNoiseLayer.active = true
        updated.noiseLayers.base.active = false
        updated.features.river.active = true
        updated.caves.underground.mouth.active = false
        updated.gridLayers.small.yaw = 77  // non-active field should survive

        let result = updated.preservingActive(from: previous)

        // `active` flags (including nested) come from `previous`.
        #expect(result.gridLayers.small.active == true)
        #expect(result.gridLayers.small.turbulenceNoiseLayer.active == false)
        #expect(result.noiseLayers.base.active == true)
        #expect(result.features.river.active == false)
        #expect(result.caves.underground.mouth.active == true)
        // Everything else comes from the mutated value.
        #expect(result.gridLayers.small.yaw == 77)
    }

    @Test @MainActor
    func fullSettingsExportUsesOneTerrainForAllSlots() async throws {
        let preset = try #require(try await FileLoader().availablePresets().first)
        let pair = try await FileLoader().loadTerrainPair(preset: preset)

        var minData = pair.min; minData.seaLevel = 123.456
        var maxData = pair.max; maxData.seaLevel = 789.012

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("full-\(UUID().uuidString).MXML")
        try TerrainExportService.writeFullSettings(minData: minData, maxData: maxData, to: url)

        let xml = try String(contentsOf: url, encoding: .utf8)
        let elementCount = xml.components(separatedBy: "value=\"TkVoxelGeneratorSettingsElement\"").count - 1
        #expect(elementCount == TerrainPreset.all.count)

        // The single terrain's Min/Max sea level appears once per slot.
        let minLine = "name=\"SeaLevel\" value=\"\(String(format: "%.6f", 123.456))\""
        let maxLine = "name=\"SeaLevel\" value=\"\(String(format: "%.6f", 789.012))\""
        #expect(xml.components(separatedBy: minLine).count - 1 == TerrainPreset.all.count)
        #expect(xml.components(separatedBy: maxLine).count - 1 == TerrainPreset.all.count)

        // Game order preserved (FloatingIslands before GrandCanyon) and Waterworld guarded.
        let fi = try #require(xml.range(of: "name=\"FloatingIslands\" value=\"TkVoxelGeneratorSettingsElement\""))
        let gc = try #require(xml.range(of: "name=\"GrandCanyon\" value=\"TkVoxelGeneratorSettingsElement\""))
        #expect(fi.lowerBound < gc.lowerBound)
        #expect(xml.contains("name=\"WaterworldPrime\""))
        #expect(!xml.contains("name=\"Waterworld\""))

        #expect(Foundation.XMLParser(data: Data(xml.utf8)).parse())
    }

    @Test
    func namedSplitExportWritesFilesNamedAfterTerrain() async throws {
        let preset = try #require(try await FileLoader().availablePresets().first)
        let pair = try await FileLoader().loadTerrainPair(preset: preset)

        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("split-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let urls = try TerrainExportService.writeNamedSplitPair(
            name: "My Cool World", minData: pair.min, maxData: pair.max, to: dir
        )

        #expect(urls.map(\.lastPathComponent) == ["MyCoolWorld_Min.xml", "MyCoolWorld_Max.xml"])
        for url in urls {
            #expect(FileManager.default.fileExists(atPath: url.path))
            #expect(try String(contentsOf: url, encoding: .utf8).contains("TkVoxelGeneratorData"))
        }
    }

    // MARK: - Terrain Settings folders

    /// A fresh, isolated container per test backed by a **unique on-disk** store.
    /// In-memory containers intermittently crash on creation under the serialized suite;
    /// the on-disk store pattern (also used by the schema tests) has been reliable. Each
    /// test keeps the returned container alive for its duration.
    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("nmt-test-\(UUID().uuidString).store")
        return try ModelContainer(
            for: TerrainSetting.self, TerrainSettingsFolder.self, TerrainSlot.self,
            configurations: ModelConfiguration(url: url)
        )
    }

    @Test @MainActor
    func folderWithMixedSlotsRoundTripsOnDisk() async throws {
        let preset = try #require(try await FileLoader().availablePresets().first)
        let pair = try await FileLoader().loadTerrainPair(preset: preset)

        // On-disk store proves the additive 3-model schema actually loads.
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("folder-store-\(UUID().uuidString).store")
        let container = try ModelContainer(
            for: TerrainSetting.self, TerrainSettingsFolder.self, TerrainSlot.self,
            configurations: ModelConfiguration(url: storeURL)
        )
        let context = container.mainContext

        let terrain = TerrainSetting(
            name: "Linked", preset: preset,
            min: TerrainMin(min: pair.min), max: TerrainMax(max: pair.max), isCustom: true
        )
        context.insert(terrain)

        let folder = TerrainSettingsFolder(name: "Set")
        context.insert(folder)
        let s0 = TerrainSlot(presetOrder: 0); s0.folder = folder; context.insert(s0)
        let s1 = TerrainSlot(presetOrder: 1); s1.folder = folder; context.insert(s1)
        s0.link(to: terrain)
        var snapMin = pair.min; snapMin.seaLevel = 99.0
        s1.setSnapshot(min: snapMin, max: pair.max, label: "Snap")
        try context.save()

        let fetched = try #require(try context.fetch(FetchDescriptor<TerrainSettingsFolder>()).first)
        let ordered = fetched.orderedSlots
        #expect(ordered.count == 2)
        #expect(ordered[0].isLinked)
        #expect(ordered[0].linkedTerrain?.name == "Linked")
        #expect(ordered[0].linkedTerrain?.isCustom == true)
        #expect(ordered[0].resolvedMin?.seaLevel == pair.min.seaLevel)
        #expect(ordered[1].isSnapshot)
        #expect(ordered[1].resolvedMin?.seaLevel == 99.0)
    }

    @Test @MainActor
    func deletingLinkedTerrainEmptiesItsSlots() async throws {
        let preset = try #require(try await FileLoader().availablePresets().first)
        let pair = try await FileLoader().loadTerrainPair(preset: preset)
        let container = try makeContainer()
        let context = container.mainContext

        let terrain = TerrainSetting(name: "L", preset: preset, min: TerrainMin(min: pair.min), max: TerrainMax(max: pair.max))
        context.insert(terrain)
        let folder = TerrainSettingsFolder(name: "Set")
        context.insert(folder)
        let slot = TerrainSlot(presetOrder: 0); slot.folder = folder; context.insert(slot)
        slot.link(to: terrain)
        try context.save()
        #expect(slot.isFilled)

        context.delete(terrain)
        try context.save()
        #expect(!slot.isFilled)
    }

    @Test @MainActor
    func folderExportEmitsGameOrderedSlots() async throws {
        let preset = try #require(try await FileLoader().availablePresets().first)
        let pair = try await FileLoader().loadTerrainPair(preset: preset)
        let container = try makeContainer()
        let context = container.mainContext

        let folder = TerrainSettingsFolder(name: "Set")
        context.insert(folder)
        for order in 0..<TerrainPreset.all.count {
            let slot = TerrainSlot(presetOrder: order); slot.folder = folder; context.insert(slot)
            var minData = pair.min; minData.seaLevel = Double(order)  // unique per slot
            slot.setSnapshot(min: minData, max: pair.max, label: "S\(order)")
        }
        try context.save()
        #expect(folder.allFilled)

        let entries = TerrainExportService.folderEntries(folder)
        #expect(entries.count == TerrainPreset.all.count)
        for (i, entry) in entries.enumerated() {
            #expect(entry.name == TerrainPreset.all[i].fileBaseName)
            #expect(entry.min.seaLevel == Double(i))
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("folder-\(UUID().uuidString).MXML")
        try NMSPropertySerializer.writeCombined(entries, to: url)
        let xml = try String(contentsOf: url, encoding: .utf8)
        #expect(xml.components(separatedBy: "value=\"TkVoxelGeneratorSettingsElement\"").count - 1 == TerrainPreset.all.count)
        #expect(Foundation.XMLParser(data: Data(xml.utf8)).parse())
    }

    @Test @MainActor
    func folderAllFilledGateFlipsOnlyWhenComplete() async throws {
        let preset = try #require(try await FileLoader().availablePresets().first)
        let pair = try await FileLoader().loadTerrainPair(preset: preset)
        let container = try makeContainer()
        let context = container.mainContext

        let folder = TerrainSettingsFolder(name: "Set")
        context.insert(folder)
        var slots: [TerrainSlot] = []
        for order in 0..<TerrainPreset.all.count {
            let slot = TerrainSlot(presetOrder: order); slot.folder = folder; context.insert(slot)
            slots.append(slot)
        }
        try context.save()
        #expect(folder.filledCount == 0)
        #expect(!folder.allFilled)

        for (i, slot) in slots.enumerated() {
            slot.setSnapshot(min: pair.min, max: pair.max, label: "x")
            #expect(folder.allFilled == (i == slots.count - 1))
        }
        #expect(folder.filledCount == TerrainPreset.all.count)
    }

    @Test
    func changedSectionsDetectsOnlyEditedSection() async throws {
        let preset = try #require(try await FileLoader().availablePresets().first)
        let pair = try await FileLoader().loadTerrainPair(preset: preset)

        var gridEdit = pair.min
        gridEdit.gridLayers.small.yaw += 10
        #expect(Set(TerrainSetting.changedSections(old: pair.min, new: gridEdit).keys) == [.grid])

        var rootEdit = pair.min
        rootEdit.seaLevel += 1
        #expect(Set(TerrainSetting.changedSections(old: pair.min, new: rootEdit).keys) == [.root])

        #expect(TerrainSetting.changedSections(old: pair.min, new: pair.min).isEmpty)
    }

    @Test @MainActor
    func granularSectionWritePersistsAndLeavesOthersIntact() async throws {
        let preset = try #require(try await FileLoader().availablePresets().first)
        let pair = try await FileLoader().loadTerrainPair(preset: preset)
        let container = try makeContainer()
        let context = container.mainContext

        let setting = TerrainSetting(
            name: "S", preset: preset,
            min: TerrainMin(min: pair.min), max: TerrainMax(max: pair.max)
        )
        context.insert(setting)
        try context.save()

        var edited = pair.min
        edited.gridLayers.small.yaw = 42
        setting.applySections(TerrainSetting.changedSections(old: pair.min, new: edited), to: .min)
        try context.save()

        let reloaded = try #require(try context.fetch(FetchDescriptor<TerrainSetting>()).first)
        #expect(reloaded.sendableMin.gridLayers.small.yaw == 42)
        // Untouched sections survive the granular write.
        #expect(reloaded.sendableMin.noiseLayers.base.height == pair.min.noiseLayers.base.height)
        #expect(reloaded.sendableMax.seaLevel == pair.max.seaLevel)
    }

    @Test @MainActor
    func sessionApplyPersistsEditsToSetting() async throws {
        let preset = try #require(try await FileLoader().availablePresets().first)
        let pair = try await FileLoader().loadTerrainPair(preset: preset)

        let container = try makeContainer()
        let context = container.mainContext
        let setting = TerrainSetting(
            name: "Auto", preset: preset,
            min: TerrainMin(min: pair.min), max: TerrainMax(max: pair.max)
        )
        context.insert(setting)
        try context.save()

        // Mimic the autosave path: edit the session, apply to the backing setting, save.
        let session = TerrainEditorSession.fromSetting(setting)
        session.minDataBinding.nested(\.seaLevel).wrappedValue = 42.5
        session.apply(to: setting)
        try context.save()

        let fetched = try #require(try context.fetch(FetchDescriptor<TerrainSetting>()).first)
        #expect(fetched.sendableMin.seaLevel == 42.5)
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
