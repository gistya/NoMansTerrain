import Foundation

public struct TkNoiseUberLayerData: Codable, Equatable, Sendable {
    public var noiseData: TkNoiseUberData
    public var active: Bool
    /// 1...4
    public var maximumLOD: Int
    /// true for rivers/caes
    public var subtract: Bool
    public var voxelType: TkNoiseVoxelTypeEnum
    /// 1.27...128.27
    public var height: Double
    /// 0.0...9999.0
    public var width: Double
    /// 0.0...1.0
    /// 0.2-1
    public var regionRatio: Double
    /// 0.95...19.95
    /// 1-5
    public var regionScale: Double
    /// 0.0...10.0
    /// 1-3
    public var regionGain: Double
    /// 0.0...20.0
    public var smoothRadius: Double
    /// -128.0...128.0
    /// -8 to?
    public var heightOffset: Double
    public var offset: TkNoiseOffsetEnum
    public var waterFade: WaterFadeType
    /// 0.0...16.0
    /// 0-2.485044
    public var plateauStratas: Double
    /// 1...4
    public var plateauSharpness: Int
    /// 0.0...1000.0
    /// 0 for continent, 100 for other
    public var plateauRegionSize: Double
    /// 0...3
    public var seedOffset: Int
    /// 0.0...100.0
    /// 0-48
    public var tileBlendMeters: Double

    public enum CodingKeys: String, CodingKey {
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
