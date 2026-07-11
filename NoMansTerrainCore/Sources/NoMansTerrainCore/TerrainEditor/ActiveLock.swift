import Foundation

/// Types that carry one or more layer `active` flags which can be preserved across a
/// bulk mutation (Set Min/Max, Randomize) when the user has "Lock active" enabled.
public protocol ActivePreserving {
    /// Returns a copy of `self` with every `active` flag taken from `previous`.
    func preservingActive(from previous: Self) -> Self
}

// MARK: - Leaf layers

extension TkNoiseUberLayerData: ActivePreserving {
    public func preservingActive(from previous: Self) -> Self {
        var copy = self
        copy.active = previous.active
        return copy
    }
}

extension TkNoiseGridData: ActivePreserving {
    public func preservingActive(from previous: Self) -> Self {
        var copy = self
        copy.active = previous.active
        copy.turbulenceNoiseLayer = copy.turbulenceNoiseLayer.preservingActive(from: previous.turbulenceNoiseLayer)
        return copy
    }
}

extension TkNoiseFeatureData: ActivePreserving {
    public func preservingActive(from previous: Self) -> Self {
        var copy = self
        copy.active = previous.active
        return copy
    }
}

extension TkNoiseCaveData: ActivePreserving {
    public func preservingActive(from previous: Self) -> Self {
        var copy = self
        copy.mouth = copy.mouth.preservingActive(from: previous.mouth)
        copy.tunnel = copy.tunnel.preservingActive(from: previous.tunnel)
        return copy
    }
}

// Types without an `active` flag: preserving is a no-op.
extension TkNoiseUberData: ActivePreserving {
    public func preservingActive(from previous: Self) -> Self { self }
}
extension TkNoiseSuperFormulaData: ActivePreserving {
    public func preservingActive(from previous: Self) -> Self { self }
}
extension TkNoiseSuperPrimitiveData: ActivePreserving {
    public func preservingActive(from previous: Self) -> Self { self }
}

// MARK: - Aggregates

extension NoiseLayers: ActivePreserving {
    public func preservingActive(from previous: NoiseLayers) -> NoiseLayers {
        var copy = self
        let keyPaths: [WritableKeyPath<NoiseLayers, TkNoiseUberLayerData>] = [
            \.base, \.hill, \.mountain, \.rock, \.underWater, \.texture, \.elevation, \.continent
        ]
        for keyPath in keyPaths {
            copy[keyPath: keyPath] = copy[keyPath: keyPath].preservingActive(from: previous[keyPath: keyPath])
        }
        return copy
    }
}

extension GridLayers: ActivePreserving {
    public func preservingActive(from previous: GridLayers) -> GridLayers {
        var copy = self
        let keyPaths: [WritableKeyPath<GridLayers, TkNoiseGridData>] = [
            \.small, \.large,
            \.resourcesHeridium, \.resourcesIridium, \.resourcesCopper, \.resourcesNickel,
            \.resourcesAluminium, \.resourcesGold, \.resourcesEmeril
        ]
        for keyPath in keyPaths {
            copy[keyPath: keyPath] = copy[keyPath: keyPath].preservingActive(from: previous[keyPath: keyPath])
        }
        return copy
    }
}

extension Features: ActivePreserving {
    public func preservingActive(from previous: Features) -> Features {
        var copy = self
        let keyPaths: [WritableKeyPath<Features, TkNoiseFeatureData>] = [
            \.river, \.crater, \.arches, \.archesSmall, \.blobs, \.blobsSmall, \.substance
        ]
        for keyPath in keyPaths {
            copy[keyPath: keyPath] = copy[keyPath: keyPath].preservingActive(from: previous[keyPath: keyPath])
        }
        return copy
    }
}

extension Caves: ActivePreserving {
    public func preservingActive(from previous: Caves) -> Caves {
        var copy = self
        copy.underground = copy.underground.preservingActive(from: previous.underground)
        return copy
    }
}

extension TkVoxelGeneratorData: ActivePreserving {
    public func preservingActive(from previous: TkVoxelGeneratorData) -> TkVoxelGeneratorData {
        var copy = self
        copy.noiseLayers = copy.noiseLayers.preservingActive(from: previous.noiseLayers)
        copy.gridLayers = copy.gridLayers.preservingActive(from: previous.gridLayers)
        copy.features = copy.features.preservingActive(from: previous.features)
        copy.caves = copy.caves.preservingActive(from: previous.caves)
        return copy
    }
}
