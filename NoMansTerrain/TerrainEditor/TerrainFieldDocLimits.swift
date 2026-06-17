import Foundation

/// Documented valid ranges from model doc comments.
enum TerrainFieldDocLimits {
    enum UberLayer {
        static let maximumLOD = 1...4
        static let height = 1.27...128.27
        static let width = 0.0...9999.0
        static let regionRatio = 0.0...1.0
        static let regionScale = 0.95...19.95
        static let regionGain = 0.0...10.0
        static let smoothRadius = 0.0...20.0
        static let heightOffset = -128.0...128.0
        static let plateauStratas = 0.0...16.0
        static let plateauSharpness = 1...4
        static let plateauRegionSize = 0.0...1000.0
        static let seedOffset = 0...3
        static let tileBlendMeters = 0.0...100.0
    }

    enum UberData {
        static let octaves = 0...10
        static let slopeGain = 0.0...1.0
        static let slopeBias = 0.0...1.0
        static let sharpToRoundFeatures = -1.0...1.0
        static let amplifyFeatures = 0.0...0.5
        static let perturbFeatures = -0.4...0.4
        static let altitudeErosion = 0.0...0.25
        static let ridgeErosion = 0.0...1.0
        static let slopeErosion = 0.0...1.0
        static let lacunarity = 1.8...2.2
        static let gain = 0.35...0.60
        static let remapFromMin = -2.0...2.0
        static let remapFromMax = -2.0...2.0
        static let remapToMin = -2.0...2.0
        static let remapToMax = -2.0...2.0
    }

    enum Grid {
        static let maximumLOD = 1...3
        static let minWidth = 0.0...9999.0
        static let maxWidth = 0.0...9999.0
        static let minHeight = 0.0...999.0
        static let maxHeight = 0.0...999.0
        static let minHeightOffset = -128.0...128.0
        static let maxHeightOffset = -128.0...128.0
        static let heightOffset = -128.0...128.0
        static let regionRatio = 0.0...1.0
        static let regionScale = 0.95...19.95
        static let yaw = 0.0...90.0
        static let pitch = 0.0...90.0
        static let roll = 0.0...90.0
        static let varyYaw = 0.0...90.0
        static let varyPitch = 0.0...90.0
        static let varyRoll = 0.0...90.0
        static let smoothRadius = 0.0...100.0
        static let randomPrimitive = 0.0...1.0
        static let tileBlendMeters = 0.0...100.0
    }

    enum Feature {
        static let width = 1.0...128.0
        static let height = 1.0...100.0
        static let regionSize = 10.0...4000.0
        static let ratio = 0.0...1.0
        static let heightVarianceAmplitude = 0.0...128.0
        static let heightVarianceFrequency = 0.0...1000.0
        static let heightOffset = -128.0...128.0
        static let tileBlendMeters = 0.0...100.0
    }

    enum SuperFormula {
        static let formM = 0.0990...9.9990
        static let formN1 = 0.0...99.90
        static let formN2 = -49.5...100.5
        static let formN3 = -49.5...100.5
    }

    enum SuperPrimitive {
        static let width = 0.0990...1.0
        static let height = 0.0990...1.0
        static let depth = 0.0990...1.0
        static let thickness = 0.0990...1.0
        static let cornerRadiusXY = 0.0...1.0
        static let cornerRadiusZ = 0.0...1.0
        static let bottomRadiusOffset = 0.0...1.0
    }
}

enum TerrainFieldRanges {
    static func doubleRange(
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

    static func intRange(
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