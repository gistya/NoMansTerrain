import Foundation

struct TkNoiseFeatureData: Codable {
    var active: Bool
    var maximumLOD: Int
    var subtract: Bool
    var trench: Bool
    var voxelType: TkNoiseVoxelTypeEnum
    var featureType: FeatureType
    /// 1.0...128.0
    var width: Double
    /// 1.0...100.0
    var height: Double
    var octaves: Int
    /// 10.0...4000.0
    var regionSize: Double
    /// 0.0...1.0
    var ratio: Double
    /// 0.0...128.0
    var heightVarianceAmplitude: Double
    /// 0.0...1000.0
    var heightVarianceFrequency: Double
    /// -128.0...128.0
    var heightOffset: Double
    var offset: TkNoiseOffsetEnum
    var smoothRadius: Double
    var seedOffset: Int
    /// 0.0...100.0
    var tileBlendMeters: Double

    enum CodingKeys: String, CodingKey {
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
