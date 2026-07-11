import Foundation

/// Types that carry the per-layer *region-mixing* fields the Region Mixer edits — coverage
/// (`regionRatio` / `ratio`), patch size (`regionScale` / `regionSize`), edge (`regionGain`,
/// noise only) and height offset — which can be preserved across a bulk mutation (Set
/// Min/Max, Randomize) when the user has "Lock region mix" enabled.
///
/// Scope matches the Region Mixer exactly: the eight noise layers, nine grid layers, seven
/// features and the two cave halves. A grid's turbulence sub-layer is *not* part of the
/// mix (it isn't shown in the Region Mixer), so it is left to be randomized normally.
public protocol RegionMixPreserving {
    /// Returns a copy of `self` with every region-mixing field taken from `previous`.
    func preservingRegionMix(from previous: Self) -> Self
}

// MARK: - Leaf layers

extension TkNoiseUberLayerData: RegionMixPreserving {
    public func preservingRegionMix(from previous: Self) -> Self {
        var copy = self
        copy.regionRatio = previous.regionRatio
        copy.regionScale = previous.regionScale
        copy.regionGain = previous.regionGain
        copy.heightOffset = previous.heightOffset
        return copy
    }
}

extension TkNoiseGridData: RegionMixPreserving {
    public func preservingRegionMix(from previous: Self) -> Self {
        var copy = self
        copy.regionRatio = previous.regionRatio
        copy.regionScale = previous.regionScale
        copy.heightOffset = previous.heightOffset
        return copy
    }
}

extension TkNoiseFeatureData: RegionMixPreserving {
    public func preservingRegionMix(from previous: Self) -> Self {
        var copy = self
        copy.ratio = previous.ratio
        copy.regionSize = previous.regionSize
        copy.heightOffset = previous.heightOffset
        return copy
    }
}

extension TkNoiseCaveData: RegionMixPreserving {
    public func preservingRegionMix(from previous: Self) -> Self {
        var copy = self
        copy.mouth = copy.mouth.preservingRegionMix(from: previous.mouth)
        copy.tunnel = copy.tunnel.preservingRegionMix(from: previous.tunnel)
        return copy
    }
}

// Types with no region-mixing fields: preserving is a no-op.
extension TkNoiseUberData: RegionMixPreserving {
    public func preservingRegionMix(from previous: Self) -> Self { self }
}
extension TkNoiseSuperFormulaData: RegionMixPreserving {
    public func preservingRegionMix(from previous: Self) -> Self { self }
}
extension TkNoiseSuperPrimitiveData: RegionMixPreserving {
    public func preservingRegionMix(from previous: Self) -> Self { self }
}

// MARK: - Aggregates

extension NoiseLayers: RegionMixPreserving {
    public func preservingRegionMix(from previous: NoiseLayers) -> NoiseLayers {
        var copy = self
        let keyPaths: [WritableKeyPath<NoiseLayers, TkNoiseUberLayerData>] = [
            \.base, \.hill, \.mountain, \.rock, \.underWater, \.texture, \.elevation, \.continent
        ]
        for keyPath in keyPaths {
            copy[keyPath: keyPath] = copy[keyPath: keyPath].preservingRegionMix(from: previous[keyPath: keyPath])
        }
        return copy
    }
}

extension GridLayers: RegionMixPreserving {
    public func preservingRegionMix(from previous: GridLayers) -> GridLayers {
        var copy = self
        let keyPaths: [WritableKeyPath<GridLayers, TkNoiseGridData>] = [
            \.small, \.large,
            \.resourcesHeridium, \.resourcesIridium, \.resourcesCopper, \.resourcesNickel,
            \.resourcesAluminium, \.resourcesGold, \.resourcesEmeril
        ]
        for keyPath in keyPaths {
            copy[keyPath: keyPath] = copy[keyPath: keyPath].preservingRegionMix(from: previous[keyPath: keyPath])
        }
        return copy
    }
}

extension Features: RegionMixPreserving {
    public func preservingRegionMix(from previous: Features) -> Features {
        var copy = self
        let keyPaths: [WritableKeyPath<Features, TkNoiseFeatureData>] = [
            \.river, \.crater, \.arches, \.archesSmall, \.blobs, \.blobsSmall, \.substance
        ]
        for keyPath in keyPaths {
            copy[keyPath: keyPath] = copy[keyPath: keyPath].preservingRegionMix(from: previous[keyPath: keyPath])
        }
        return copy
    }
}

extension Caves: RegionMixPreserving {
    public func preservingRegionMix(from previous: Caves) -> Caves {
        var copy = self
        copy.underground = copy.underground.preservingRegionMix(from: previous.underground)
        return copy
    }
}

extension TkVoxelGeneratorData: RegionMixPreserving {
    public func preservingRegionMix(from previous: TkVoxelGeneratorData) -> TkVoxelGeneratorData {
        var copy = self
        copy.noiseLayers = copy.noiseLayers.preservingRegionMix(from: previous.noiseLayers)
        copy.gridLayers = copy.gridLayers.preservingRegionMix(from: previous.gridLayers)
        copy.features = copy.features.preservingRegionMix(from: previous.features)
        copy.caves = copy.caves.preservingRegionMix(from: previous.caves)
        return copy
    }
}
