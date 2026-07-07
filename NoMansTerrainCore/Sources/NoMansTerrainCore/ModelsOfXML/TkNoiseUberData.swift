import Foundation

public struct TkNoiseUberData: Codable, Equatable, Sendable {
    /// 0...10
    public var octaves: Int
    /// 0.0...1.0
    /// -0.3...0.9
    public var slopeGain: Double
    /// 0.0...1.0
    /// -0.2...0.5
    public var slopeBias: Double
    /// -1.0...1.0
    /// -1, 0, 1
    public var sharpToRoundFeatures: Double
    /// 0.0...0.5
    public var amplifyFeatures: Double
    /// -0.4...0.4
    /// -0.1...0.21
    public var perturbFeatures: Double
    /// 0.0...0.25
    public var altitudeErosion: Double
    /// 0.0...1.0
    /// 0 or 1
    public var ridgeErosion: Double
    /// 0.0...1.0
    /// 0 or 1
    public var slopeErosion: Double
    /// 1.8...2.2
    /// 2
    public var lacunarity: Double
    /// 0.35...0.60
    /// 0.5
    public var gain: Double
    /// -2.0...2.0
    /// 0-0.5
    public var remapFromMin: Double
    /// -2.0...2.0
    /// 0.6-1.0
    public var remapFromMax: Double
    /// -2.0...2.0
    /// 0
    public var remapToMin: Double
    /// -2.0...2.0
    /// 0.9-1.0
    public var remapToMax: Double
    public var debugNoiseType: DebugNoiseType

    public enum CodingKeys: String, CodingKey {
        case octaves = "Octaves"
        case slopeGain = "SlopeGain"
        case slopeBias = "SlopeBias"
        case sharpToRoundFeatures = "SharpToRoundFeatures"
        case amplifyFeatures = "AmplifyFeatures"
        case perturbFeatures = "PerturbFeatures"
        case altitudeErosion = "AltitudeErosion"
        case ridgeErosion = "RidgeErosion"
        case slopeErosion = "SlopeErosion"
        case lacunarity = "Lacunarity"
        case gain = "Gain"
        case remapFromMin = "Remap From Min"
        case remapFromMax = "Remap From Max"
        case remapToMin = "Remap To Min"
        case remapToMax = "Remap To Max"
        case debugNoiseType = "DebugNoiseType"
    }
}
