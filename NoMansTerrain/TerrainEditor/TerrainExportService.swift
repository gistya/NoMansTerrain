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
}

/// Generates a randomized Min/Max terrain pair for every preset and writes them to
/// disk in one batch — a "mass dump" of random terrain files for No Man's Sky.
enum TerrainRandomBatch {
    /// Number of presets a full run produces a Min/Max pair for.
    static var presetCount: Int { TerrainPreset.all.count }

    /// Randomizes and writes a Min/Max pair for each preset into `directory`
    /// (under `Min/` and `Max/` subfolders). Reports 1-based progress after each
    /// preset completes. Runs off the main actor.
    @discardableResult
    static func generateAll(
        into directory: URL,
        globalMin: TkVoxelGeneratorData,
        globalMax: TkVoxelGeneratorData,
        progress: @MainActor @Sendable (_ completed: Int, _ total: Int) -> Void
    ) async throws -> Int {
        let loader = FileLoader()
        let presets = TerrainPreset.all
        for (index, preset) in presets.enumerated() {
            var minData = globalMin
            var maxData = globalMax
            TerrainEditorOperations.randomizeRoot(
                minData: &minData,
                maxData: &maxData,
                refMin: globalMin,
                refMax: globalMax
            )
            _ = try await loader.write(terrain: preset.minTerrain, data: minData, to: directory)
            _ = try await loader.write(terrain: preset.maxTerrain, data: maxData, to: directory)
            await progress(index + 1, presets.count)
        }
        return presets.count
    }
}