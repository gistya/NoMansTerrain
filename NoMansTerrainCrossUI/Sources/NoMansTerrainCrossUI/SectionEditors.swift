import Foundation
import NoMansTerrainCore
import SwiftCrossUI

/// Makes a field `Binding` from a parent binding + key path (SwiftCrossUI has no
/// dynamic-member binding, so this is the explicit equivalent of the macOS `.nested(_:)`).
func bind<Root, Value>(_ parent: Binding<Root>, _ kp: WritableKeyPath<Root, Value>) -> Binding<Value> {
    Binding(get: { parent.wrappedValue[keyPath: kp] }, set: { parent.wrappedValue[keyPath: kp] = $0 })
}

private typealias Doc = TerrainFieldDocLimits

// MARK: - General (root scalars)

struct GeneralEditor: View {
    @Binding var min: TkVoxelGeneratorData
    @Binding var max: TkVoxelGeneratorData
    let globalMin: TkVoxelGeneratorData
    let globalMax: TkVoxelGeneratorData

    private func range(_ lo: Double, _ hi: Double) -> ClosedRange<Double> {
        TerrainEditableRanges.doubleRange(aggregatedMin: lo, aggregatedMax: hi)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Seed & Water").font(.headline)
                MinMaxSeedRow(label: "Base Seed", minSeed: bind($min, \.baseSeed), maxSeed: bind($max, \.baseSeed))
                MinMaxDoubleRow(label: "Sea Level", minValue: bind($min, \.seaLevel), maxValue: bind($max, \.seaLevel), range: range(globalMin.seaLevel, globalMax.seaLevel))
                MinMaxDoubleRow(label: "Beach Height", minValue: bind($min, \.beachHeight), maxValue: bind($max, \.beachHeight), range: range(globalMin.beachHeight, globalMax.beachHeight))
                MinMaxDoubleRow(label: "No Sea Base Level", minValue: bind($min, \.noSeaBaseLevel), maxValue: bind($max, \.noSeaBaseLevel), range: range(globalMin.noSeaBaseLevel, globalMax.noSeaBaseLevel))
                MinMaxDoubleRow(label: "Water Fade In Distance", minValue: bind($min, \.waterFadeInDistance), maxValue: bind($max, \.waterFadeInDistance), range: range(globalMin.waterFadeInDistance, globalMax.waterFadeInDistance))

                Text("Voxel Types").font(.headline)
                MinMaxEnumRow(label: "Building Voxel Type", minValue: bind($min, \.buildingVoxelType.noiseVoxelType), maxValue: bind($max, \.buildingVoxelType.noiseVoxelType))
                MinMaxEnumRow(label: "Resource Voxel Type", minValue: bind($min, \.resourceVoxelType.noiseVoxelType), maxValue: bind($max, \.resourceVoxelType.noiseVoxelType))

                Text("Caves").font(.headline)
                MinMaxDoubleRow(label: "Minimum Cave Depth", minValue: bind($min, \.minimumCaveDepth), maxValue: bind($max, \.minimumCaveDepth), range: range(globalMin.minimumCaveDepth, globalMax.minimumCaveDepth))
                MinMaxDoubleRow(label: "Cave Roof Smoothing Dist", minValue: bind($min, \.caveRoofSmoothingDist), maxValue: bind($max, \.caveRoofSmoothingDist), range: range(globalMin.caveRoofSmoothingDist, globalMax.caveRoofSmoothingDist))
                MinMaxDoubleRow(label: "Max Sea Level Cave Depth", minValue: bind($min, \.maximumSeaLevelCaveDepth), maxValue: bind($max, \.maximumSeaLevelCaveDepth), range: range(globalMin.maximumSeaLevelCaveDepth, globalMax.maximumSeaLevelCaveDepth))

                Text("Building").font(.headline)
                MinMaxDoubleRow(label: "Building Texture Radius", minValue: bind($min, \.buildingTextureRadius), maxValue: bind($max, \.buildingTextureRadius), range: range(globalMin.buildingTextureRadius, globalMax.buildingTextureRadius))
                MinMaxDoubleRow(label: "Building Smoothing Radius", minValue: bind($min, \.buildingSmoothingRadius), maxValue: bind($max, \.buildingSmoothingRadius), range: range(globalMin.buildingSmoothingRadius, globalMax.buildingSmoothingRadius))
                MinMaxDoubleRow(label: "Building Smoothing Height", minValue: bind($min, \.buildingSmoothingHeight), maxValue: bind($max, \.buildingSmoothingHeight), range: range(globalMin.buildingSmoothingHeight, globalMax.buildingSmoothingHeight))
            }
            .padding(.trailing, 8)
        }
    }
}

// MARK: - Noise uber data (nested)

struct UberDataEditor: View {
    @Binding var min: TkNoiseUberData
    @Binding var max: TkNoiseUberData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            MinMaxIntRow(label: "Octaves", minValue: bind($min, \.octaves), maxValue: bind($max, \.octaves), range: Doc.UberData.octaves)
            MinMaxDoubleRow(label: "Slope Gain", minValue: bind($min, \.slopeGain), maxValue: bind($max, \.slopeGain), range: Doc.UberData.slopeGain)
            MinMaxDoubleRow(label: "Slope Bias", minValue: bind($min, \.slopeBias), maxValue: bind($max, \.slopeBias), range: Doc.UberData.slopeBias)
            MinMaxDoubleRow(label: "Sharp To Round", minValue: bind($min, \.sharpToRoundFeatures), maxValue: bind($max, \.sharpToRoundFeatures), range: Doc.UberData.sharpToRoundFeatures)
            MinMaxDoubleRow(label: "Amplify Features", minValue: bind($min, \.amplifyFeatures), maxValue: bind($max, \.amplifyFeatures), range: Doc.UberData.amplifyFeatures)
            MinMaxDoubleRow(label: "Perturb Features", minValue: bind($min, \.perturbFeatures), maxValue: bind($max, \.perturbFeatures), range: Doc.UberData.perturbFeatures)
            MinMaxDoubleRow(label: "Altitude Erosion", minValue: bind($min, \.altitudeErosion), maxValue: bind($max, \.altitudeErosion), range: Doc.UberData.altitudeErosion)
            MinMaxDoubleRow(label: "Ridge Erosion", minValue: bind($min, \.ridgeErosion), maxValue: bind($max, \.ridgeErosion), range: Doc.UberData.ridgeErosion)
            MinMaxDoubleRow(label: "Slope Erosion", minValue: bind($min, \.slopeErosion), maxValue: bind($max, \.slopeErosion), range: Doc.UberData.slopeErosion)
            MinMaxDoubleRow(label: "Lacunarity", minValue: bind($min, \.lacunarity), maxValue: bind($max, \.lacunarity), range: Doc.UberData.lacunarity)
            MinMaxDoubleRow(label: "Gain", minValue: bind($min, \.gain), maxValue: bind($max, \.gain), range: Doc.UberData.gain)
            MinMaxDoubleRow(label: "Remap From Min", minValue: bind($min, \.remapFromMin), maxValue: bind($max, \.remapFromMin), range: Doc.UberData.remapFromMin)
            MinMaxDoubleRow(label: "Remap From Max", minValue: bind($min, \.remapFromMax), maxValue: bind($max, \.remapFromMax), range: Doc.UberData.remapFromMax)
            MinMaxDoubleRow(label: "Remap To Min", minValue: bind($min, \.remapToMin), maxValue: bind($max, \.remapToMin), range: Doc.UberData.remapToMin)
            MinMaxDoubleRow(label: "Remap To Max", minValue: bind($min, \.remapToMax), maxValue: bind($max, \.remapToMax), range: Doc.UberData.remapToMax)
            MinMaxEnumRow(label: "Debug Noise Type", minValue: bind($min, \.debugNoiseType), maxValue: bind($max, \.debugNoiseType))
        }
    }
}

// MARK: - Noise uber layer

struct UberLayerEditor: View {
    @Binding var min: TkNoiseUberLayerData
    @Binding var max: TkNoiseUberLayerData
    @State private var showNoiseData = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 8) {
                MinMaxBoolRow(label: "Active", minValue: bind($min, \.active), maxValue: bind($max, \.active))
                MinMaxIntRow(label: "Maximum LOD", minValue: bind($min, \.maximumLOD), maxValue: bind($max, \.maximumLOD), range: Doc.UberLayer.maximumLOD)
                MinMaxBoolRow(label: "Subtract", minValue: bind($min, \.subtract), maxValue: bind($max, \.subtract))
                MinMaxEnumRow(label: "Voxel Type", minValue: bind($min, \.voxelType.noiseVoxelType), maxValue: bind($max, \.voxelType.noiseVoxelType))
                MinMaxDoubleRow(label: "Height", minValue: bind($min, \.height), maxValue: bind($max, \.height), range: Doc.UberLayer.height)
                MinMaxDoubleRow(label: "Width", minValue: bind($min, \.width), maxValue: bind($max, \.width), range: Doc.UberLayer.width)
                MinMaxDoubleRow(label: "Region Ratio", minValue: bind($min, \.regionRatio), maxValue: bind($max, \.regionRatio), range: Doc.UberLayer.regionRatio)
                MinMaxDoubleRow(label: "Region Scale", minValue: bind($min, \.regionScale), maxValue: bind($max, \.regionScale), range: Doc.UberLayer.regionScale)
                MinMaxDoubleRow(label: "Region Gain", minValue: bind($min, \.regionGain), maxValue: bind($max, \.regionGain), range: Doc.UberLayer.regionGain)
            }
            VStack(alignment: .leading, spacing: 8) {
                MinMaxDoubleRow(label: "Smooth Radius", minValue: bind($min, \.smoothRadius), maxValue: bind($max, \.smoothRadius), range: Doc.UberLayer.smoothRadius)
                MinMaxDoubleRow(label: "Height Offset", minValue: bind($min, \.heightOffset), maxValue: bind($max, \.heightOffset), range: Doc.UberLayer.heightOffset)
                MinMaxEnumRow(label: "Offset", minValue: bind($min, \.offset.offsetType), maxValue: bind($max, \.offset.offsetType))
                MinMaxEnumRow(label: "Water Fade", minValue: bind($min, \.waterFade), maxValue: bind($max, \.waterFade))
                MinMaxDoubleRow(label: "Plateau Stratas", minValue: bind($min, \.plateauStratas), maxValue: bind($max, \.plateauStratas), range: Doc.UberLayer.plateauStratas)
                MinMaxIntRow(label: "Plateau Sharpness", minValue: bind($min, \.plateauSharpness), maxValue: bind($max, \.plateauSharpness), range: Doc.UberLayer.plateauSharpness)
                MinMaxDoubleRow(label: "Plateau Region Size", minValue: bind($min, \.plateauRegionSize), maxValue: bind($max, \.plateauRegionSize), range: Doc.UberLayer.plateauRegionSize)
                MinMaxIntRow(label: "Seed Offset", minValue: bind($min, \.seedOffset), maxValue: bind($max, \.seedOffset), range: Doc.UberLayer.seedOffset)
                MinMaxDoubleRow(label: "Tile Blend Meters", minValue: bind($min, \.tileBlendMeters), maxValue: bind($max, \.tileBlendMeters), range: Doc.UberLayer.tileBlendMeters)
            }
            Button(showNoiseData ? "▾ Noise Data" : "▸ Noise Data") { showNoiseData.toggle() }
            if showNoiseData {
                UberDataEditor(min: bind($min, \.noiseData), max: bind($max, \.noiseData))
            }
        }
    }
}

// MARK: - Grid layer

struct GridLayerEditor: View {
    @Binding var min: TkNoiseGridData
    @Binding var max: TkNoiseGridData
    @State private var showTurbulence = false
    @State private var showSF1 = false
    @State private var showSF2 = false
    @State private var showSP = false

    private func agg(_ lo: Int, _ hi: Int) -> ClosedRange<Int> { Swift.min(lo, hi)...Swift.max(lo, hi) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 8) {
                MinMaxBoolRow(label: "Active", minValue: bind($min, \.active), maxValue: bind($max, \.active))
                MinMaxIntRow(label: "Maximum LOD", minValue: bind($min, \.maximumLOD), maxValue: bind($max, \.maximumLOD), range: Doc.Grid.maximumLOD)
                MinMaxBoolRow(label: "Subtract", minValue: bind($min, \.subtract), maxValue: bind($max, \.subtract))
                MinMaxBoolRow(label: "Swap ZY", minValue: bind($min, \.swapZY), maxValue: bind($max, \.swapZY))
                MinMaxBoolRow(label: "Hemisphere", minValue: bind($min, \.hemisphere), maxValue: bind($max, \.hemisphere))
                MinMaxEnumRow(label: "Voxel Type", minValue: bind($min, \.voxelType.noiseVoxelType), maxValue: bind($max, \.voxelType.noiseVoxelType))
                MinMaxEnumRow(label: "Noise Grid Type", minValue: bind($min, \.noiseGridType), maxValue: bind($max, \.noiseGridType))
                MinMaxDoubleRow(label: "Min Width", minValue: bind($min, \.minWidth), maxValue: bind($max, \.minWidth), range: Doc.Grid.minWidth)
                MinMaxDoubleRow(label: "Max Width", minValue: bind($min, \.maxWidth), maxValue: bind($max, \.maxWidth), range: Doc.Grid.maxWidth)
                MinMaxDoubleRow(label: "Min Height", minValue: bind($min, \.minHeight), maxValue: bind($max, \.minHeight), range: Doc.Grid.minHeight)
                MinMaxDoubleRow(label: "Max Height", minValue: bind($min, \.maxHeight), maxValue: bind($max, \.maxHeight), range: Doc.Grid.maxHeight)
                MinMaxDoubleRow(label: "Min Height Offset", minValue: bind($min, \.minHeightOffset), maxValue: bind($max, \.minHeightOffset), range: Doc.Grid.minHeightOffset)
                MinMaxDoubleRow(label: "Max Height Offset", minValue: bind($min, \.maxHeightOffset), maxValue: bind($max, \.maxHeightOffset), range: Doc.Grid.maxHeightOffset)
                MinMaxDoubleRow(label: "Height Offset", minValue: bind($min, \.heightOffset), maxValue: bind($max, \.heightOffset), range: Doc.Grid.heightOffset)
                MinMaxEnumRow(label: "Offset", minValue: bind($min, \.offset.offsetType), maxValue: bind($max, \.offset.offsetType))
                MinMaxDoubleRow(label: "Region Ratio", minValue: bind($min, \.regionRatio), maxValue: bind($max, \.regionRatio), range: Doc.Grid.regionRatio)
                MinMaxDoubleRow(label: "Region Scale", minValue: bind($min, \.regionScale), maxValue: bind($max, \.regionScale), range: Doc.Grid.regionScale)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Orientation").font(.headline)
                MinMaxDoubleRow(label: "Yaw", minValue: bind($min, \.yaw), maxValue: bind($max, \.yaw), range: Doc.Grid.yaw)
                MinMaxDoubleRow(label: "Pitch", minValue: bind($min, \.pitch), maxValue: bind($max, \.pitch), range: Doc.Grid.pitch)
                MinMaxDoubleRow(label: "Roll", minValue: bind($min, \.roll), maxValue: bind($max, \.roll), range: Doc.Grid.roll)
                MinMaxDoubleRow(label: "Vary Yaw", minValue: bind($min, \.varyYaw), maxValue: bind($max, \.varyYaw), range: Doc.Grid.varyYaw)
                MinMaxDoubleRow(label: "Vary Pitch", minValue: bind($min, \.varyPitch), maxValue: bind($max, \.varyPitch), range: Doc.Grid.varyPitch)
                MinMaxDoubleRow(label: "Vary Roll", minValue: bind($min, \.varyRoll), maxValue: bind($max, \.varyRoll), range: Doc.Grid.varyRoll)
                MinMaxDoubleRow(label: "Smooth Radius", minValue: bind($min, \.smoothRadius), maxValue: bind($max, \.smoothRadius), range: Doc.Grid.smoothRadius)
                MinMaxIntRow(label: "Seed Offset", minValue: bind($min, \.seedOffset), maxValue: bind($max, \.seedOffset), range: agg(min.seedOffset, max.seedOffset))
                MinMaxDoubleRow(label: "Random Primitive", minValue: bind($min, \.randomPrimitive), maxValue: bind($max, \.randomPrimitive), range: Doc.Grid.randomPrimitive)
                MinMaxDoubleRow(label: "Tile Blend Meters", minValue: bind($min, \.tileBlendMeters), maxValue: bind($max, \.tileBlendMeters), range: Doc.Grid.tileBlendMeters)
            }

            Button(showTurbulence ? "▾ Turbulence Noise Layer" : "▸ Turbulence Noise Layer") { showTurbulence.toggle() }
            if showTurbulence {
                UberLayerEditor(min: bind($min, \.turbulenceNoiseLayer), max: bind($max, \.turbulenceNoiseLayer))
            }
            Button(showSF1 ? "▾ Super Formula 1" : "▸ Super Formula 1") { showSF1.toggle() }
            if showSF1 { SuperFormulaEditor(min: bind($min, \.superFormula1), max: bind($max, \.superFormula1)) }
            Button(showSF2 ? "▾ Super Formula 2" : "▸ Super Formula 2") { showSF2.toggle() }
            if showSF2 { SuperFormulaEditor(min: bind($min, \.superFormula2), max: bind($max, \.superFormula2)) }
            Button(showSP ? "▾ Super Primitive" : "▸ Super Primitive") { showSP.toggle() }
            if showSP { SuperPrimitiveEditor(min: bind($min, \.superPrimitive), max: bind($max, \.superPrimitive)) }
        }
    }
}

// MARK: - Feature

struct FeatureEditor: View {
    @Binding var min: TkNoiseFeatureData
    @Binding var max: TkNoiseFeatureData

    private func agg(_ lo: Int, _ hi: Int) -> ClosedRange<Int> { Swift.min(lo, hi)...Swift.max(lo, hi) }
    private func agg(_ lo: Double, _ hi: Double) -> ClosedRange<Double> { Swift.min(lo, hi)...Swift.max(lo, hi) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            MinMaxBoolRow(label: "Active", minValue: bind($min, \.active), maxValue: bind($max, \.active))
            MinMaxIntRow(label: "Maximum LOD", minValue: bind($min, \.maximumLOD), maxValue: bind($max, \.maximumLOD), range: agg(min.maximumLOD, max.maximumLOD))
            MinMaxBoolRow(label: "Subtract", minValue: bind($min, \.subtract), maxValue: bind($max, \.subtract))
            MinMaxBoolRow(label: "Trench", minValue: bind($min, \.trench), maxValue: bind($max, \.trench))
            MinMaxEnumRow(label: "Voxel Type", minValue: bind($min, \.voxelType.noiseVoxelType), maxValue: bind($max, \.voxelType.noiseVoxelType))
            MinMaxEnumRow(label: "Feature Type", minValue: bind($min, \.featureType), maxValue: bind($max, \.featureType))
            MinMaxDoubleRow(label: "Width", minValue: bind($min, \.width), maxValue: bind($max, \.width), range: Doc.Feature.width)
            MinMaxDoubleRow(label: "Height", minValue: bind($min, \.height), maxValue: bind($max, \.height), range: Doc.Feature.height)
            MinMaxIntRow(label: "Octaves", minValue: bind($min, \.octaves), maxValue: bind($max, \.octaves), range: agg(min.octaves, max.octaves))
            MinMaxDoubleRow(label: "Region Size", minValue: bind($min, \.regionSize), maxValue: bind($max, \.regionSize), range: Doc.Feature.regionSize)
            MinMaxDoubleRow(label: "Ratio", minValue: bind($min, \.ratio), maxValue: bind($max, \.ratio), range: Doc.Feature.ratio)
            MinMaxDoubleRow(label: "Height Var Amplitude", minValue: bind($min, \.heightVarianceAmplitude), maxValue: bind($max, \.heightVarianceAmplitude), range: Doc.Feature.heightVarianceAmplitude)
            MinMaxDoubleRow(label: "Height Var Frequency", minValue: bind($min, \.heightVarianceFrequency), maxValue: bind($max, \.heightVarianceFrequency), range: Doc.Feature.heightVarianceFrequency)
            MinMaxDoubleRow(label: "Height Offset", minValue: bind($min, \.heightOffset), maxValue: bind($max, \.heightOffset), range: Doc.Feature.heightOffset)
            MinMaxEnumRow(label: "Offset", minValue: bind($min, \.offset.offsetType), maxValue: bind($max, \.offset.offsetType))
            MinMaxDoubleRow(label: "Smooth Radius", minValue: bind($min, \.smoothRadius), maxValue: bind($max, \.smoothRadius), range: agg(min.smoothRadius, max.smoothRadius))
            MinMaxIntRow(label: "Seed Offset", minValue: bind($min, \.seedOffset), maxValue: bind($max, \.seedOffset), range: agg(min.seedOffset, max.seedOffset))
            MinMaxDoubleRow(label: "Tile Blend Meters", minValue: bind($min, \.tileBlendMeters), maxValue: bind($max, \.tileBlendMeters), range: Doc.Feature.tileBlendMeters)
        }
    }
}

// MARK: - Super Formula / Primitive

struct SuperFormulaEditor: View {
    @Binding var min: TkNoiseSuperFormulaData
    @Binding var max: TkNoiseSuperFormulaData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            MinMaxDoubleRow(label: "Form M", minValue: bind($min, \.formM), maxValue: bind($max, \.formM), range: Doc.SuperFormula.formM)
            MinMaxDoubleRow(label: "Form N1", minValue: bind($min, \.formN1), maxValue: bind($max, \.formN1), range: Doc.SuperFormula.formN1)
            MinMaxDoubleRow(label: "Form N2", minValue: bind($min, \.formN2), maxValue: bind($max, \.formN2), range: Doc.SuperFormula.formN2)
            MinMaxDoubleRow(label: "Form N3", minValue: bind($min, \.formN3), maxValue: bind($max, \.formN3), range: Doc.SuperFormula.formN3)
        }
    }
}

struct SuperPrimitiveEditor: View {
    @Binding var min: TkNoiseSuperPrimitiveData
    @Binding var max: TkNoiseSuperPrimitiveData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            MinMaxDoubleRow(label: "Width", minValue: bind($min, \.width), maxValue: bind($max, \.width), range: Doc.SuperPrimitive.width)
            MinMaxDoubleRow(label: "Height", minValue: bind($min, \.height), maxValue: bind($max, \.height), range: Doc.SuperPrimitive.height)
            MinMaxDoubleRow(label: "Depth", minValue: bind($min, \.depth), maxValue: bind($max, \.depth), range: Doc.SuperPrimitive.depth)
            MinMaxDoubleRow(label: "Thickness", minValue: bind($min, \.thickness), maxValue: bind($max, \.thickness), range: Doc.SuperPrimitive.thickness)
            MinMaxDoubleRow(label: "Corner Radius XY", minValue: bind($min, \.cornerRadiusXY), maxValue: bind($max, \.cornerRadiusXY), range: Doc.SuperPrimitive.cornerRadiusXY)
            MinMaxDoubleRow(label: "Corner Radius Z", minValue: bind($min, \.cornerRadiusZ), maxValue: bind($max, \.cornerRadiusZ), range: Doc.SuperPrimitive.cornerRadiusZ)
            MinMaxDoubleRow(label: "Bottom Radius Offset", minValue: bind($min, \.bottomRadiusOffset), maxValue: bind($max, \.bottomRadiusOffset), range: Doc.SuperPrimitive.bottomRadiusOffset)
        }
    }
}
