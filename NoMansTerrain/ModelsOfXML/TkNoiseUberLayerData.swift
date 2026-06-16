import Foundation

struct TkNoiseUberLayerData: Codable {
    var noiseData: TkNoiseUberData
    var active: Bool
    /// 1...4
    var maximumLOD: Int
    /// true for rivers/caes
    var subtract: Bool
    var voxelType: TkNoiseVoxelTypeEnum
    /// 1.27...128.27
    var height: Double
    /// 0.0...9999.0
    var width: Double
    /// 0.0...1.0
    /// 0.2-1
    var regionRatio: Double
    /// 0.95...19.95
    /// 1-5
    var regionScale: Double
    /// 0.0...10.0
    /// 1-3
    var regionGain: Double
    /// 0.0...20.0
    var smoothRadius: Double
    /// -128.0...128.0
    /// -8 to?
    var heightOffset: Double
    var offset: TkNoiseOffsetEnum
    var waterFade: WaterFadeType
    /// 0.0...16.0
    /// 0-2.485044
    var plateauStratas: Double
    /// 1...4
    var plateauSharpness: Int
    /// 0.0...1000.0
    /// 0 for continent, 100 for other
    var plateauRegionSize: Double
    /// 0...3
    var seedOffset: Int
    /// 0.0...100.0
    /// 0-48
    var tileBlendMeters: Double

    enum CodingKeys: String, CodingKey {
        case noiseData = "NoiseData"
        case active = "Active"
        case maximumLOD = "MaximumLOD"
        case subtract = "Subtract"
        case voxelType = "VoxelType"
        case height = "Height"
        case width = "Width"
        case regionRatio = "RegionRatio"
        case regionScale = "RegionScale"
        case regionGain = "RegionGain"
        case smoothRadius = "SmoothRadius"
        case heightOffset = "HeightOffset"
        case offset = "Offset"
        case waterFade = "WaterFade"
        case plateauStratas = "PlateauStratas"
        case plateauSharpness = "PlateauSharpness"
        case plateauRegionSize = "PlateauRegionSize"
        case seedOffset = "SeedOffset"
        case tileBlendMeters = "TileBlendMeters"
    }
}
