import Foundation

public struct TkNoiseFeatureData: Codable, Equatable {
    public var active: Bool
    public var maximumLOD: Int
    public var subtract: Bool
    public var trench: Bool
    public var voxelType: TkNoiseVoxelTypeEnum
    public var featureType: FeatureType
    /// 1.0...128.0
    public var width: Double
    /// 1.0...100.0
    public var height: Double
    public var octaves: Int
    /// 10.0...4000.0
    public var regionSize: Double
    /// 0.0...1.0
    public var ratio: Double
    /// 0.0...128.0
    public var heightVarianceAmplitude: Double
    /// 0.0...1000.0
    public var heightVarianceFrequency: Double
    /// -128.0...128.0
    public var heightOffset: Double
    public var offset: TkNoiseOffsetEnum
    public var smoothRadius: Double
    public var seedOffset: Int
    /// 0.0...100.0
    public var tileBlendMeters: Double

    public enum CodingKeys: String, CodingKey {
        case active = "Active"
        case maximumLOD = "MaximumLOD"
        case subtract = "Subtract"
        case trench = "Trench"
        case voxelType = "VoxelType"
        case featureType = "FeatureType"
        case width = "Width"
        case height = "Height"
        case octaves = "Octaves"
        case regionSize = "RegionSize"
        case ratio = "Ratio"
        case heightVarianceAmplitude = "HeightVarianceAmplitude"
        case heightVarianceFrequency = "HeightVarianceFrequency"
        case heightOffset = "HeightOffset"
        case offset = "Offset"
        case smoothRadius = "SmoothRadius"
        case seedOffset = "SeedOffset"
        case tileBlendMeters = "TileBlendMeters"
    }
}
