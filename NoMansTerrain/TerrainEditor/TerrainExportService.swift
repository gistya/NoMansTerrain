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