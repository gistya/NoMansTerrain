import NoMansTerrainCore
import Foundation

enum TerrainExportService {
    static func writeXMLPair(
        preset: TerrainPreset,
        minData: TkVoxelGeneratorData,
        maxData: TkVoxelGeneratorData,
        to directory: URL
    ) async throws -> (minURL: URL, maxURL: URL) {
        let loader = FileLoader()
        let minURL = try await loader.write(terrain: preset.minTerrain, data: minData, to: directory)
        let maxURL = try await loader.write(terrain: preset.maxTerrain, data: maxData, to: directory)
        return (minURL, maxURL)
    }

    static func writeXMLPairToTemporaryDirectory(
        preset: TerrainPreset,
        minData: TkVoxelGeneratorData,
        maxData: TkVoxelGeneratorData
    ) async throws -> [URL] {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("terrain-export-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let pair = try await writeXMLPair(preset: preset, minData: minData, maxData: maxData, to: directory)
        return [pair.minURL, pair.maxURL]
    }

    // MARK: - Single-terrain export (Workflow A)

    /// Writes one terrain as a `<Name>_Min.xml` / `<Name>_Max.xml` pair directly into
    /// `directory`, named after the (sanitized) terrain name. Returns the two URLs.
    @discardableResult
    static func writeNamedSplitPair(
        name: String,
        minData: TkVoxelGeneratorData,
        maxData: TkVoxelGeneratorData,
        to directory: URL
    ) throws -> [URL] {
        let base = sanitizedFileName(name)
        let minURL = directory.appendingPathComponent("\(base)_Min.xml")
        let maxURL = directory.appendingPathComponent("\(base)_Max.xml")
        try NMSPropertySerializer.write(limit: .min, minData, to: minURL)
        try NMSPropertySerializer.write(limit: .max, maxData, to: maxURL)
        return [minURL, maxURL]
    }

    /// Writes a full `voxelgeneratorsettings.MXML` where **every** preset slot uses this
    /// single terrain's Min/Max — so every planet in-game renders the terrain under
    /// development. Slots are emitted in game order via `TerrainPreset.all`.
    static func writeFullSettings(
        minData: TkVoxelGeneratorData,
        maxData: TkVoxelGeneratorData,
        to url: URL
    ) throws {
        let entries = TerrainPreset.all.map {
            NMSPropertySerializer.CombinedEntry(name: $0.fileBaseName, min: minData, max: maxData)
        }
        try NMSPropertySerializer.writeCombined(entries, to: url)
    }

    /// Resolves a folder's filled slots into combined-file entries in game order. Reads
    /// SwiftData models, so it runs on the main actor; the returned entries are `Sendable`
    /// and can be handed to `NMSPropertySerializer.writeCombined` off the main thread.
    @MainActor
    static func folderEntries(_ folder: TerrainSettingsFolder) -> [NMSPropertySerializer.CombinedEntry] {
        let all = TerrainPreset.all
        return folder.orderedSlots.compactMap { slot in
            guard all.indices.contains(slot.presetOrder),
                  let min = slot.resolvedMin,
                  let max = slot.resolvedMax
            else { return nil }
            return NMSPropertySerializer.CombinedEntry(name: all[slot.presetOrder].fileBaseName, min: min, max: max)
        }
    }

    /// Filesystem-safe base name derived from a user terrain name (e.g. "My Cool World"
    /// → "MyCoolWorld"). Falls back to "Terrain" when empty.
    static func sanitizedFileName(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics
        let mapped = name.unicodeScalars.map { allowed.contains($0) ? Character($0) : " " }
        let collapsed = String(mapped).split(separator: " ").joined()
        return collapsed.isEmpty ? "Terrain" : collapsed
    }
}

/// Generates a randomized Min/Max terrain pair for every preset and writes them to
/// disk in one batch — a "mass dump" of random terrain files for No Man's Sky.
enum TerrainRandomBatch {
    /// File name of the combined "big daddy" settings file written at the directory
    /// root — the name No Man's Sky uses for it.
    static let combinedFileName = "voxelgeneratorsettings.MXML"

    /// Number of presets a full run produces a Min/Max pair for.
    static var presetCount: Int { TerrainPreset.all.count }

    /// Total progress steps: one per preset pair, plus the final combined file.
    static var totalSteps: Int { presetCount + 1 }

    /// Randomizes and writes a Min/Max pair for each preset into `directory`
    /// (under `Min/` and `Max/` subfolders), then assembles the single combined
    /// `cTkVoxelGeneratorSettingsArray` file from the same data at the directory
    /// root. Reports 1-based progress after each step. Runs off the main actor.
    @discardableResult
    static func generateAll(
        into directory: URL,
        globalMin: TkVoxelGeneratorData,
        globalMax: TkVoxelGeneratorData,
        smartRegionMix: Bool = false,
        progress: @MainActor @Sendable (_ completed: Int, _ total: Int) -> Void
    ) async throws -> Int {
        let loader = FileLoader()
        let presets = TerrainPreset.all
        let total = presets.count + 1

        var entries: [NMSPropertySerializer.CombinedEntry] = []
        entries.reserveCapacity(presets.count)

        for (index, preset) in presets.enumerated() {
            var minData = globalMin
            var maxData = globalMax
            TerrainEditorOperations.randomizeRoot(
                minData: &minData,
                maxData: &maxData,
                refMin: globalMin,
                refMax: globalMax
            )
            if smartRegionMix {
                var rng = SystemRandomNumberGenerator()
                SmartRegionMix.apply(min: &minData, max: &maxData, using: &rng)
            }
            _ = try await loader.write(terrain: preset.minTerrain, data: minData, to: directory)
            _ = try await loader.write(terrain: preset.maxTerrain, data: maxData, to: directory)
            entries.append(.init(name: preset.fileBaseName, min: minData, max: maxData))
            await progress(index + 1, total)
        }

        try NMSPropertySerializer.writeCombined(
            entries,
            to: directory.appendingPathComponent(combinedFileName)
        )
        await progress(total, total)

        return presets.count
    }
}