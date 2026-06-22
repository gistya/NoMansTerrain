import Foundation

/// Types that carry layer `maximumLOD` fields which can be forced to their maximum
/// (highest detail) when the user has "Lock LOD to max" enabled. Lower LOD values cause
/// in-game rendering problems, so this pins them high across bulk operations.
protocol MaxLODApplying {
    /// Returns a copy of `self` with every `maximumLOD` set to its type's maximum.
    func applyingMaxLOD() -> Self
}

private enum LODMax {
    /// Noise layers allow LOD 1–4.
    static let uber = TerrainFieldDocLimits.UberLayer.maximumLOD.upperBound   // 4
    /// Grid layers allow LOD 1–3.
    static let grid = TerrainFieldDocLimits.Grid.maximumLOD.upperBound        // 3
    /// Features have no documented cap; the bundled presets only ever use up to 3.
    static let feature = 3
}

// MARK: - Leaf layers

extension TkNoiseUberLayerData: MaxLODApplying {
    func applyingMaxLOD() -> Self {
        var copy = self
        copy.maximumLOD = LODMax.uber
        return copy
    }
}

extension TkNoiseGridData: MaxLODApplying {
    func applyingMaxLOD() -> Self {
        var copy = self
        copy.maximumLOD = LODMax.grid
        copy.turbulenceNoiseLayer = copy.turbulenceNoiseLayer.applyingMaxLOD()
        return copy
    }
}

extension TkNoiseFeatureData: MaxLODApplying {
    func applyingMaxLOD() -> Self {
        var copy = self
        copy.maximumLOD = LODMax.feature
        return copy
    }
}

extension TkNoiseCaveData: MaxLODApplying {
    func applyingMaxLOD() -> Self {
        var copy = self
        copy.mouth = copy.mouth.applyingMaxLOD()
        copy.tunnel = copy.tunnel.applyingMaxLOD()
        return copy
    }
}

// Types without a `maximumLOD`: no-op.
extension TkNoiseUberData: MaxLODApplying {
    func applyingMaxLOD() -> Self { self }
}
extension TkNoiseSuperFormulaData: MaxLODApplying {
    func applyingMaxLOD() -> Self { self }
}
extension TkNoiseSuperPrimitiveData: MaxLODApplying {
    func applyingMaxLOD() -> Self { self }
}

// MARK: - Aggregates

extension NoiseLayers: MaxLODApplying {
    func applyingMaxLOD() -> NoiseLayers {
        var copy = self
        let keyPaths: [WritableKeyPath<NoiseLayers, TkNoiseUberLayerData>] = [
            \.base, \.hill, \.mountain, \.rock, \.underWater, \.texture, \.elevation, \.continent
        ]
        for keyPath in keyPaths { copy[keyPath: keyPath] = copy[keyPath: keyPath].applyingMaxLOD() }
        return copy
    }
}

extension GridLayers: MaxLODApplying {
    func applyingMaxLOD() -> GridLayers {
        var copy = self
        let keyPaths: [WritableKeyPath<GridLayers, TkNoiseGridData>] = [
            \.small, \.large,
            \.resourcesHeridium, \.resourcesIridium, \.resourcesCopper, \.resourcesNickel,
            \.resourcesAluminium, \.resourcesGold, \.resourcesEmeril
        ]
        for keyPath in keyPaths { copy[keyPath: keyPath] = copy[keyPath: keyPath].applyingMaxLOD() }
        return copy
    }
}

extension Features: MaxLODApplying {
    func applyingMaxLOD() -> Features {
        var copy = self
        let keyPaths: [WritableKeyPath<Features, TkNoiseFeatureData>] = [
            \.river, \.crater, \.arches, \.archesSmall, \.blobs, \.blobsSmall, \.substance
        ]
        for keyPath in keyPaths { copy[keyPath: keyPath] = copy[keyPath: keyPath].applyingMaxLOD() }
        return copy
    }
}

extension Caves: MaxLODApplying {
    func applyingMaxLOD() -> Caves {
        var copy = self
        copy.underground = copy.underground.applyingMaxLOD()
        return copy
    }
}

extension TkVoxelGeneratorData: MaxLODApplying {
    func applyingMaxLOD() -> TkVoxelGeneratorData {
        var copy = self
        copy.noiseLayers = copy.noiseLayers.applyingMaxLOD()
        copy.gridLayers = copy.gridLayers.applyingMaxLOD()
        copy.features = copy.features.applyingMaxLOD()
        copy.caves = copy.caves.applyingMaxLOD()
        return copy
    }
}
