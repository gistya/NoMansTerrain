import Foundation

/// Which family a region layer belongs to (drives the Region Mixer's tabs).
public enum RegionCategory: String, Sendable, CaseIterable, Identifiable {
    case noise, grid, feature, cave
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .noise: "Noise Layers"
        case .grid: "Grid Layers"
        case .feature: "Features"
        case .cave: "Caves"
        }
    }
}

/// One region layer addressed by key paths into a `TkVoxelGeneratorData`: the shared,
/// UI-agnostic description of the fields the Region Mixer edits. Both the macOS SwiftUI
/// editor and the cross-platform SwiftCrossUI editor build their controls from this, so the
/// (fragile) key-path list lives in exactly one place.
///
/// `scaleRange` is the native range of `scale`: 0.95…19.95 (RegionScale) for noise/grid,
/// 10…4000 (RegionSize) for features/caves. `gain` is nil where a layer has no RegionGain.
public struct RegionLayerField: Identifiable {
    public let id: String
    public let name: String
    public let colorIndex: Int
    public let category: RegionCategory
    public let active: WritableKeyPath<TkVoxelGeneratorData, Bool>
    public let ratio: WritableKeyPath<TkVoxelGeneratorData, Double>
    public let scale: WritableKeyPath<TkVoxelGeneratorData, Double>
    public let gain: WritableKeyPath<TkVoxelGeneratorData, Double>?
    public let elevation: WritableKeyPath<TkVoxelGeneratorData, Double>
    public let scaleRange: ClosedRange<Double>
}

/// The full set of region layers the mixer controls, grouped by category.
public enum RegionLayerRegistry {
    /// Common patch-size domain the preview sampler / Auto-Tier work in (noise/grid store
    /// their RegionScale directly in this range; features/caves are remapped onto it).
    public static let canonicalScaleRange: ClosedRange<Double> = 0.95...19.95

    public static let noise: [RegionLayerField] = {
        let layers: [(String, WritableKeyPath<NoiseLayers, TkNoiseUberLayerData>)] = [
            ("Base", \.base), ("Hill", \.hill), ("Mountain", \.mountain), ("Rock", \.rock),
            ("Under Water", \.underWater), ("Texture", \.texture), ("Elevation", \.elevation), ("Continent", \.continent)
        ]
        return layers.enumerated().map { index, entry in
            let (name, lp) = entry
            func kp<V>(_ leaf: WritableKeyPath<TkNoiseUberLayerData, V>) -> WritableKeyPath<TkVoxelGeneratorData, V> {
                let root: WritableKeyPath<TkVoxelGeneratorData, NoiseLayers> = \.noiseLayers
                return root.appending(path: lp.appending(path: leaf))
            }
            return RegionLayerField(
                id: "noise.\(name)", name: name, colorIndex: index, category: .noise,
                active: kp(\.active), ratio: kp(\.regionRatio), scale: kp(\.regionScale),
                gain: kp(\.regionGain), elevation: kp(\.heightOffset), scaleRange: canonicalScaleRange
            )
        }
    }()

    public static let grid: [RegionLayerField] = {
        let layers: [(String, WritableKeyPath<GridLayers, TkNoiseGridData>)] = [
            ("Small", \.small), ("Large", \.large),
            ("Heridium", \.resourcesHeridium), ("Iridium", \.resourcesIridium),
            ("Copper", \.resourcesCopper), ("Nickel", \.resourcesNickel),
            ("Aluminium", \.resourcesAluminium), ("Gold", \.resourcesGold), ("Emeril", \.resourcesEmeril)
        ]
        return layers.enumerated().map { index, entry in
            let (name, lp) = entry
            func kp<V>(_ leaf: WritableKeyPath<TkNoiseGridData, V>) -> WritableKeyPath<TkVoxelGeneratorData, V> {
                let root: WritableKeyPath<TkVoxelGeneratorData, GridLayers> = \.gridLayers
                return root.appending(path: lp.appending(path: leaf))
            }
            return RegionLayerField(
                id: "grid.\(name)", name: name, colorIndex: index, category: .grid,
                active: kp(\.active), ratio: kp(\.regionRatio), scale: kp(\.regionScale),
                gain: nil, elevation: kp(\.heightOffset), scaleRange: canonicalScaleRange
            )
        }
    }()

    public static let features: [RegionLayerField] = {
        let layers: [(String, WritableKeyPath<Features, TkNoiseFeatureData>)] = [
            ("River", \.river), ("Crater", \.crater), ("Arches", \.arches),
            ("Arches Small", \.archesSmall), ("Blobs", \.blobs), ("Blobs Small", \.blobsSmall),
            ("Substance", \.substance)
        ]
        return layers.enumerated().map { index, entry in
            let (name, lp) = entry
            func kp<V>(_ leaf: WritableKeyPath<TkNoiseFeatureData, V>) -> WritableKeyPath<TkVoxelGeneratorData, V> {
                let root: WritableKeyPath<TkVoxelGeneratorData, Features> = \.features
                return root.appending(path: lp.appending(path: leaf))
            }
            return RegionLayerField(
                id: "feature.\(name)", name: name, colorIndex: 8 + index, category: .feature,
                active: kp(\.active), ratio: kp(\.ratio), scale: kp(\.regionSize),
                gain: nil, elevation: kp(\.heightOffset), scaleRange: 10...4000
            )
        }
    }()

    public static let caves: [RegionLayerField] = {
        let layers: [(String, WritableKeyPath<TkNoiseCaveData, TkNoiseFeatureData>)] = [
            ("Cave Mouth", \.mouth), ("Cave Tunnel", \.tunnel)
        ]
        return layers.enumerated().map { index, entry in
            let (name, lp) = entry
            func kp<V>(_ leaf: WritableKeyPath<TkNoiseFeatureData, V>) -> WritableKeyPath<TkVoxelGeneratorData, V> {
                let caves: WritableKeyPath<TkVoxelGeneratorData, Caves> = \.caves
                let underground: WritableKeyPath<Caves, TkNoiseCaveData> = \.underground
                let root: WritableKeyPath<TkVoxelGeneratorData, TkNoiseCaveData> = caves.appending(path: underground)
                return root.appending(path: lp.appending(path: leaf))
            }
            return RegionLayerField(
                id: "cave.\(name)", name: name, colorIndex: 15 + index, category: .cave,
                active: kp(\.active), ratio: kp(\.ratio), scale: kp(\.regionSize),
                gain: nil, elevation: kp(\.heightOffset), scaleRange: 10...4000
            )
        }
    }()

    public static let all: [RegionLayerField] = noise + grid + features + caves

    public static func layers(_ category: RegionCategory) -> [RegionLayerField] {
        switch category {
        case .noise: noise
        case .grid: grid
        case .feature: features
        case .cave: caves
        }
    }

    /// Reads a `RegionLayerState` snapshot of one layer from terrain `data` (scale remapped
    /// onto the canonical domain so the preview sampler stays meaningful for features/caves).
    public static func state(_ field: RegionLayerField, in data: TkVoxelGeneratorData) -> RegionLayerState {
        RegionLayerState(
            id: field.id, name: field.name, colorIndex: field.colorIndex,
            active: data[keyPath: field.active],
            ratio: data[keyPath: field.ratio],
            scale: remap(data[keyPath: field.scale], from: field.scaleRange, to: canonicalScaleRange),
            gain: field.gain.map { data[keyPath: $0] } ?? 2,
            hasGain: field.gain != nil,
            elevation: data[keyPath: field.elevation]
        )
    }

    /// Linearly remaps `v` from one range to another, clamped to `dst`.
    public static func remap(_ v: Double, from src: ClosedRange<Double>, to dst: ClosedRange<Double>) -> Double {
        guard src.upperBound > src.lowerBound else { return dst.lowerBound }
        let t = min(max((v - src.lowerBound) / (src.upperBound - src.lowerBound), 0), 1)
        return dst.lowerBound + t * (dst.upperBound - dst.lowerBound)
    }
}
