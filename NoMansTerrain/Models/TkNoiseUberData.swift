import Foundation

struct TkNoiseUberData: Codable {
    /// 0...10
    var octaves: Int
    /// 0.0...1.0
    /// -0.3...0.9
    var slopeGain: Double
    /// 0.0...1.0
    /// -0.2...0.5
    var slopeBias: Double
    /// -1.0...1.0
    /// -1, 0, 1
    var sharpToRoundFeatures: Double
    /// 0.0...0.5
    var amplifyFeatures: Double
    /// -0.4...0.4
    /// -0.1...0.21
    var perturbFeatures: Double
    /// 0.0...0.25
    var altitudeErosion: Double
    /// 0.0...1.0
    /// 0 or 1
    var ridgeErosion: Double
    /// 0.0...1.0
    /// 0 or 1
    var slopeErosion: Double
    /// 1.8...2.2
    /// 2
    var lacunarity: Double
    /// 0.35...0.60
    /// 0.5
    var gain: Double
    /// -2.0...2.0
    /// 0-0.5
    var remapFromMin: Double
    /// -2.0...2.0
    /// 0.6-1.0
    var remapFromMax: Double
    /// -2.0...2.0
    /// 0
    var remapToMin: Double
    /// -2.0...2.0
    /// 0.9-1.0
    var remapToMax: Double
    var debugNoiseType: DebugNoiseType

    enum CodingKeys: String, CodingKey {
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
