import Foundation

struct TkNoiseGridData: Codable {
    var active: Bool
    /// 1...3
    var maximumLOD: Int
    var subtract: Bool
    var swapZY: Bool
    var hemisphere: Bool
    var voxelType: TkNoiseVoxelTypeEnum
    var noiseGridType: NoiseGridType
    var filename: String
    /// 0.0...9999.0
    var minWidth: Double
    /// 0.0...9999.0
    var maxWidth: Double
    /// 0.0...999.0
    var minHeight: Double
    /// 0.0...999.0
    var maxHeight: Double
    /// -128.0...128.0
    var minHeightOffset: Double
    /// -128.0...128.0
    var maxHeightOffset: Double
    /// -128.0...128.0
    var heightOffset: Double
    var offset: TkNoiseOffsetEnum
    /// 0.0...1.0
    var regionRatio: Double
    /// 0.95...19.95
    var regionScale: Double
    var turbulenceNoiseLayer: TkNoiseUberLayerData
    /// 0.0...90.0
    var yaw: Double
    /// 0.0...90.0
    var pitch: Double
    /// 0.0...90.0
    var roll: Double
    /// 0.0...90.0
    /// 0/45/90
    var varyYaw: Double
    /// 0.0...90.0
    var varyPitch: Double
    /// 0.0...90.0
    var varyRoll: Double
    /// 0.0...100.0
    /// 0-20
    var smoothRadius: Double
    /// ? 2 ?
    var seedOffset: Int
    /// 0.0...1.0
    var randomPrimitive: Double
    var superFormula1: TkNoiseSuperFormulaData
    var superFormula2: TkNoiseSuperFormulaData
    var superPrimitive: TkNoiseSuperPrimitiveData
    /// 0.0...100.0
    /// 0-16
    var tileBlendMeters: Double

    enum CodingKeys: String, CodingKey {
        case active = "Active"
        case maximumLOD = "MaximumLOD"
        case subtract = "Subtract"
        case swapZY = "SwapZY"
        case hemisphere = "Hemisphere"
        case voxelType = "VoxelType"
        case noiseGridType = "NoiseGridType"
        case filename = "Filename"
        case minWidth = "MinWidth"
        case maxWidth = "MaxWidth"
        case minHeight = "MinHeight"
        case maxHeight = "MaxHeight"
        case minHeightOffset = "MinHeightOffset"
        case maxHeightOffset = "MaxHeightOffset"
        case heightOffset = "HeightOffset"
        case offset = "Offset"
        case regionRatio = "RegionRatio"
        case regionScale = "RegionScale"
        case turbulenceNoiseLayer = "TurbulenceNoiseLayer"
        case yaw = "Yaw"
        case pitch = "Pitch"
        case roll = "Roll"
        case varyYaw = "VaryYaw"
        case varyPitch = "VaryPitch"
        case varyRoll = "VaryRoll"
        case smoothRadius = "SmoothRadius"
        case seedOffset = "SeedOffset"
        case randomPrimitive = "RandomPrimitive"
        case superFormula1 = "SuperFormula1"
        case superFormula2 = "SuperFormula2"
        case superPrimitive = "SuperPrimitive"
        case tileBlendMeters = "TileBlendMeters"
    }
}
