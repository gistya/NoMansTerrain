import NoMansTerrainCore
import Foundation
import Observation

@MainActor
@Observable
final class TerrainLimitsCatalog {
    private(set) var globalMin: TkVoxelGeneratorData?
    private(set) var globalMax: TkVoxelGeneratorData?
    private(set) var availablePresets: [TerrainPreset] = []
    private(set) var loadError: String?
    private(set) var isLoading = false

    func loadIfNeeded() async {
        guard globalMin == nil, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let loader = FileLoader()
            let settings = try await loader.makeModelsOfXML()
            let aggregate = try settings.aggregate()
            globalMin = aggregate.min
            globalMax = aggregate.max
            availablePresets = try await loader.availablePresets(in: .main)
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }
}