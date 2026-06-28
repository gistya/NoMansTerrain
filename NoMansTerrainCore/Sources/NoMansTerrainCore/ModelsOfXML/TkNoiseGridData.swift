import Foundation

public struct TkNoiseGridData: Codable, Equatable {
    public var active: Bool
    /// 1...3
    public var maximumLOD: Int
    public var subtract: Bool
    public var swapZY: Bool
    public var hemisphere: Bool
    public var voxelType: TkNoiseVoxelTypeEnum
    public var noiseGridType: NoiseGridType
    public var filename: String
    /// 0.0...9999.0
    public var minWidth: Double
    /// 0.0...9999.0
    public var maxWidth: Double
    /// 0.0...999.0
    public var minHeight: Double
    /// 0.0...999.0
    public var maxHeight: Double
    /// -128.0...128.0
    public var minHeightOffset: Double
    /// -128.0...128.0
    public var maxHeightOffset: Double
    /// -128.0...128.0
    public var heightOffset: Double
    public var offset: TkNoiseOffsetEnum
    /// 0.0...1.0
    public var regionRatio: Double
    /// 0.95...19.95
    public var regionScale: Double
    public var turbulenceNoiseLayer: TkNoiseUberLayerData
    /// 0.0...90.0
    public var yaw: Double
    /// 0.0...90.0
    public var pitch: Double
    /// 0.0...90.0
    public var roll: Double
    /// 0.0...90.0
    /// 0/45/90
    public var varyYaw: Double
    /// 0.0...90.0
    public var varyPitch: Double
    /// 0.0...90.0
    public var varyRoll: Double
    /// 0.0...100.0
    /// 0-20
    public var smoothRadius: Double
    /// ? 2 ?
    public var seedOffset: Int
    /// 0.0...1.0
    public var randomPrimitive: Double
    public var superFormula1: TkNoiseSuperFormulaData
    public var superFormula2: TkNoiseSuperFormulaData
    public var superPrimitive: TkNoiseSuperPrimitiveData
    /// 0.0...100.0
    /// 0-16
    public var tileBlendMeters: Double

    public enum CodingKeys: String, CodingKey {
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
