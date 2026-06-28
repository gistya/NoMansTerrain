import Foundation

/// Documented valid ranges from model doc comments.
public enum TerrainFieldDocLimits {
    public enum UberLayer {
        public static let maximumLOD = 1...4
        public static let height = 1.27...128.27
        public static let width = 0.0...9999.0
        public static let regionRatio = 0.0...1.0
        public static let regionScale = 0.95...19.95
        public static let regionGain = 0.0...10.0
        public static let smoothRadius = 0.0...20.0
        public static let heightOffset = -128.0...128.0
        public static let plateauStratas = 0.0...16.0
        public static let plateauSharpness = 1...4
        public static let plateauRegionSize = 0.0...1000.0
        public static let seedOffset = 0...3
        public static let tileBlendMeters = 0.0...100.0
    }

    public enum UberData {
        public static let octaves = 0...10
        public static let slopeGain = 0.0...1.0
        public static let slopeBias = 0.0...1.0
        public static let sharpToRoundFeatures = -1.0...1.0
        public static let amplifyFeatures = 0.0...0.5
        public static let perturbFeatures = -0.4...0.4
        public static let altitudeErosion = 0.0...0.25
        public static let ridgeErosion = 0.0...1.0
        public static let slopeErosion = 0.0...1.0
        public static let lacunarity = 1.8...2.2
        public static let gain = 0.35...0.60
        public static let remapFromMin = -2.0...2.0
        public static let remapFromMax = -2.0...2.0
        public static let remapToMin = -2.0...2.0
        public static let remapToMax = -2.0...2.0
    }

    public enum Grid {
        public static let maximumLOD = 1...3
        public static let minWidth = 0.0...9999.0
        public static let maxWidth = 0.0...9999.0
        public static let minHeight = 0.0...999.0
        public static let maxHeight = 0.0...999.0
        public static let minHeightOffset = -128.0...128.0
        public static let maxHeightOffset = -128.0...128.0
        public static let heightOffset = -128.0...128.0
        public static let regionRatio = 0.0...1.0
        public static let regionScale = 0.95...19.95
        public static let yaw = 0.0...90.0
        public static let pitch = 0.0...90.0
        public static let roll = 0.0...90.0
        public static let varyYaw = 0.0...90.0
        public static let varyPitch = 0.0...90.0
        public static let varyRoll = 0.0...90.0
        public static let smoothRadius = 0.0...100.0
        public static let randomPrimitive = 0.0...1.0
        public static let tileBlendMeters = 0.0...100.0
    }

    public enum Feature {
        public static let width = 1.0...128.0
        public static let height = 1.0...100.0
        public static let regionSize = 10.0...4000.0
        public static let ratio = 0.0...1.0
        public static let heightVarianceAmplitude = 0.0...128.0
        public static let heightVarianceFrequency = 0.0...1000.0
        public static let heightOffset = -128.0...128.0
        public static let tileBlendMeters = 0.0...100.0
    }

    public enum SuperFormula {
        public static let formM = 0.0990...9.9990
        public static let formN1 = 0.0...99.90
        public static let formN2 = -49.5...100.5
        public static let formN3 = -49.5...100.5
    }

    public enum SuperPrimitive {
        public static let width = 0.0990...1.0
        public static let height = 0.0990...1.0
        public static let depth = 0.0990...1.0
        public static let thickness = 0.0990...1.0
        public static let cornerRadiusXY = 0.0...1.0
        public static let cornerRadiusZ = 0.0...1.0
        public static let bottomRadiusOffset = 0.0...1.0
    }
}

public enum TerrainFieldRanges {
    public static func doubleRange(
        documented: ClosedRange<Double>,
        aggregatedMin: Double,
        aggregatedMax: Double,
        hasDocComment: Bool
    ) -> ClosedRange<Double> {
        if hasDocComment {
            documented
        } else {
            TerrainEditableRanges.doubleRange(
                aggregatedMin: aggregatedMin,
                aggregatedMax: aggregatedMax
            )
        }
    }

    public static func intRange(
        documented: ClosedRange<Int>,
        aggregatedMin: Int,
        aggregatedMax: Int,
        hasDocComment: Bool
    ) -> ClosedRange<Int> {
        if hasDocComment {
            documented
        } else {
            min(aggregatedMin, aggregatedMax)...max(aggregatedMin, aggregatedMax)
        }
    }
}