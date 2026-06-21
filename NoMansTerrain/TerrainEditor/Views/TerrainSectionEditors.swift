import SwiftUI

// MARK: - Root

struct RootTerrainFormEditor: View {
    @Bindable var session: TerrainEditorSession
    let globalMin: TkVoxelGeneratorData
    let globalMax: TkVoxelGeneratorData
    let preset: TerrainPreset

    var body: some View {
        Form {
            Section("Document") {
                TextField("Name", text: session.nameBinding)
                    .writingToolsBehavior(.limited)
                LabeledContent("Preset", value: preset.displayName)
                LabeledContent("Min File") {
                    Text(preset.minFileName)
                        .font(.caption.monospaced())
                }
                LabeledContent("Max File") {
                    Text(preset.maxFileName)
                        .font(.caption.monospaced())
                }
            }

            RootTerrainEditorContent(
                session: session,
                globalMin: globalMin,
                globalMax: globalMax
            )
        }
        .formStyle(.grouped)
        .terrainScrollEdgeEffect()
    }
}

struct RootTerrainEditorContent: View {
    @Bindable var session: TerrainEditorSession
    let globalMin: TkVoxelGeneratorData
    let globalMax: TkVoxelGeneratorData

    var body: some View {
        Section {
            SectionActionBar(
                minValue: session.minDataBinding,
                maxValue: session.maxDataBinding,
                applyGlobalMin: { data in
                    var scalars = globalMin
                    scalars.noiseLayers = data.noiseLayers
                    scalars.gridLayers = data.gridLayers
                    scalars.features = data.features
                    scalars.caves = data.caves
                    TerrainEditorOperations.applyGlobalMin(to: &data, from: scalars)
                },
                applyGlobalMax: { data in
                    var scalars = globalMax
                    scalars.noiseLayers = data.noiseLayers
                    scalars.gridLayers = data.gridLayers
                    scalars.features = data.features
                    scalars.caves = data.caves
                    TerrainEditorOperations.applyGlobalMax(to: &data, from: scalars)
                },
                randomize: { min, max in
                    TerrainEditorOperations.randomizeRootScalars(
                        minData: &min,
                        maxData: &max,
                        refMin: globalMin,
                        refMax: globalMax
                    )
                },
                scope: SectionScopeChoice(
                    allLabel: "All Values",
                    thisLabel: "Just the General Tab",
                    // "All values" replaces the whole document with the (effective) global,
                    // so it cascades to every layer — and respects the Absolute-limits toggle.
                    applyAllMin: { data in TerrainEditorOperations.applyGlobalMin(to: &data, from: globalMin) },
                    applyAllMax: { data in TerrainEditorOperations.applyGlobalMax(to: &data, from: globalMax) }
                )
            )

            Button("Activate All Layers", systemImage: "checkmark.circle.fill") {
                mutatePair(session.minDataBinding, session.maxDataBinding) { min, max in
                    TerrainEditorOperations.activateAll(&min)
                    TerrainEditorOperations.activateAll(&max)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Turn on every layer/feature toggle in both the Min and Max files")
        }

        Section("Seed & Water") {
            MinMaxSeedField(label: "Base Seed", minSeed: session.minDataBinding.nested(\.baseSeed), maxSeed: session.maxDataBinding.nested(\.baseSeed))
            MinMaxDoubleField(label: "Sea Level", minValue: session.minDataBinding.nested(\.seaLevel), maxValue: session.maxDataBinding.nested(\.seaLevel), range: fieldRange(globalMin.seaLevel, globalMax.seaLevel))
            MinMaxDoubleField(label: "Beach Height", minValue: session.minDataBinding.nested(\.beachHeight), maxValue: session.maxDataBinding.nested(\.beachHeight), range: fieldRange(globalMin.beachHeight, globalMax.beachHeight))
            MinMaxDoubleField(label: "No Sea Base Level", minValue: session.minDataBinding.nested(\.noSeaBaseLevel), maxValue: session.maxDataBinding.nested(\.noSeaBaseLevel), range: fieldRange(globalMin.noSeaBaseLevel, globalMax.noSeaBaseLevel))
            MinMaxDoubleField(label: "Water Fade In Distance", minValue: session.minDataBinding.nested(\.waterFadeInDistance), maxValue: session.maxDataBinding.nested(\.waterFadeInDistance), range: fieldRange(globalMin.waterFadeInDistance, globalMax.waterFadeInDistance))
        }

        Section("Voxel Types") {
            MinMaxEnumField(label: "Building Voxel Type", minValue: session.minDataBinding.nested(\.buildingVoxelType).nested(\.noiseVoxelType), maxValue: session.maxDataBinding.nested(\.buildingVoxelType).nested(\.noiseVoxelType))
            MinMaxEnumField(label: "Resource Voxel Type", minValue: session.minDataBinding.nested(\.resourceVoxelType).nested(\.noiseVoxelType), maxValue: session.maxDataBinding.nested(\.resourceVoxelType).nested(\.noiseVoxelType))
        }

        Section("Caves") {
            MinMaxDoubleField(label: "Minimum Cave Depth", minValue: session.minDataBinding.nested(\.minimumCaveDepth), maxValue: session.maxDataBinding.nested(\.minimumCaveDepth), range: fieldRange(globalMin.minimumCaveDepth, globalMax.minimumCaveDepth))
            MinMaxDoubleField(label: "Cave Roof Smoothing Dist", minValue: session.minDataBinding.nested(\.caveRoofSmoothingDist), maxValue: session.maxDataBinding.nested(\.caveRoofSmoothingDist), range: fieldRange(globalMin.caveRoofSmoothingDist, globalMax.caveRoofSmoothingDist))
            MinMaxDoubleField(label: "Maximum Sea Level Cave Depth", minValue: session.minDataBinding.nested(\.maximumSeaLevelCaveDepth), maxValue: session.maxDataBinding.nested(\.maximumSeaLevelCaveDepth), range: fieldRange(globalMin.maximumSeaLevelCaveDepth, globalMax.maximumSeaLevelCaveDepth))
        }

        Section("Building") {
            MinMaxDoubleField(label: "Building Texture Radius", minValue: session.minDataBinding.nested(\.buildingTextureRadius), maxValue: session.maxDataBinding.nested(\.buildingTextureRadius), range: fieldRange(globalMin.buildingTextureRadius, globalMax.buildingTextureRadius))
            MinMaxDoubleField(label: "Building Smoothing Radius", minValue: session.minDataBinding.nested(\.buildingSmoothingRadius), maxValue: session.maxDataBinding.nested(\.buildingSmoothingRadius), range: fieldRange(globalMin.buildingSmoothingRadius, globalMax.buildingSmoothingRadius))
            MinMaxDoubleField(label: "Building Smoothing Height", minValue: session.minDataBinding.nested(\.buildingSmoothingHeight), maxValue: session.maxDataBinding.nested(\.buildingSmoothingHeight), range: fieldRange(globalMin.buildingSmoothingHeight, globalMax.buildingSmoothingHeight))
        }
    }

    /// Range derived purely from the bundle's aggregated limits. The field itself
    /// widens this to include its current values, so we deliberately avoid reading
    /// `session.minData`/`maxData` here — doing so would re-render the whole General
    /// form on every field edit.
    private func fieldRange(_ lo: Double, _ hi: Double) -> ClosedRange<Double> {
        TerrainEditableRanges.doubleRange(aggregatedMin: lo, aggregatedMax: hi)
    }
}

// MARK: - Noise Layer

struct UberLayerFormEditor: View {
    let title: String
    @Binding var minLayer: TkNoiseUberLayerData
    @Binding var maxLayer: TkNoiseUberLayerData
    let globalMin: TkNoiseUberLayerData
    let globalMax: TkNoiseUberLayerData

    var body: some View {
        Form {
            UberLayerEditorContent(
                title: title,
                minLayer: $minLayer,
                maxLayer: $maxLayer,
                globalMin: globalMin,
                globalMax: globalMax
            )
        }
        .formStyle(.grouped)
        .terrainScrollEdgeEffect()
    }
}

struct UberLayerEditorContent: View {
    let title: String
    @Binding var minLayer: TkNoiseUberLayerData
    @Binding var maxLayer: TkNoiseUberLayerData
    let globalMin: TkNoiseUberLayerData
    let globalMax: TkNoiseUberLayerData

    @State private var showNoiseData = false

    var body: some View {
        Section {
            SectionActionBar(
                minValue: $minLayer,
                maxValue: $maxLayer,
                applyGlobalMin: { TerrainEditorOperations.applyGlobalMin(to: &$0, from: globalMin) },
                applyGlobalMax: { TerrainEditorOperations.applyGlobalMax(to: &$0, from: globalMax) },
                randomize: { min, max in
                    TerrainEditorOperations.randomizeUberLayer(
                        min: &min,
                        max: &max,
                        refMin: globalMin,
                        refMax: globalMax
                    )
                }
            )
        }

        Section("Noise Data", isExpanded: $showNoiseData) {
            UberDataEditorContent(
                minData: $minLayer.nested(\.noiseData),
                maxData: $maxLayer.nested(\.noiseData),
                globalMin: globalMin.noiseData,
                globalMax: globalMax.noiseData
            )
        }

        Section("Layer Settings") {
            MinMaxBoolField(label: "Active", minValue: $minLayer.nested(\.active), maxValue: $maxLayer.nested(\.active))
            MinMaxIntField(label: "Maximum LOD", minValue: $minLayer.nested(\.maximumLOD), maxValue: $maxLayer.nested(\.maximumLOD), range: TerrainFieldDocLimits.UberLayer.maximumLOD)
            MinMaxBoolField(label: "Subtract", minValue: $minLayer.nested(\.subtract), maxValue: $maxLayer.nested(\.subtract))
            MinMaxEnumField(label: "Voxel Type", minValue: $minLayer.nested(\.voxelType).nested(\.noiseVoxelType), maxValue: $maxLayer.nested(\.voxelType).nested(\.noiseVoxelType))
            MinMaxDoubleField(label: "Height", minValue: $minLayer.nested(\.height), maxValue: $maxLayer.nested(\.height), range: TerrainFieldDocLimits.UberLayer.height)
            MinMaxDoubleField(label: "Width", minValue: $minLayer.nested(\.width), maxValue: $maxLayer.nested(\.width), range: TerrainFieldDocLimits.UberLayer.width)
            MinMaxDoubleField(label: "Region Ratio", minValue: $minLayer.nested(\.regionRatio), maxValue: $maxLayer.nested(\.regionRatio), range: TerrainFieldDocLimits.UberLayer.regionRatio)
            MinMaxDoubleField(label: "Region Scale", minValue: $minLayer.nested(\.regionScale), maxValue: $maxLayer.nested(\.regionScale), range: TerrainFieldDocLimits.UberLayer.regionScale)
            MinMaxDoubleField(label: "Region Gain", minValue: $minLayer.nested(\.regionGain), maxValue: $maxLayer.nested(\.regionGain), range: TerrainFieldDocLimits.UberLayer.regionGain)
            MinMaxDoubleField(label: "Smooth Radius", minValue: $minLayer.nested(\.smoothRadius), maxValue: $maxLayer.nested(\.smoothRadius), range: TerrainFieldDocLimits.UberLayer.smoothRadius)
            MinMaxDoubleField(label: "Height Offset", minValue: $minLayer.nested(\.heightOffset), maxValue: $maxLayer.nested(\.heightOffset), range: TerrainFieldDocLimits.UberLayer.heightOffset)
            MinMaxEnumField(label: "Offset", minValue: $minLayer.nested(\.offset).nested(\.offsetType), maxValue: $maxLayer.nested(\.offset).nested(\.offsetType))
            MinMaxEnumField(label: "Water Fade", minValue: $minLayer.nested(\.waterFade), maxValue: $maxLayer.nested(\.waterFade))
            MinMaxDoubleField(label: "Plateau Stratas", minValue: $minLayer.nested(\.plateauStratas), maxValue: $maxLayer.nested(\.plateauStratas), range: TerrainFieldDocLimits.UberLayer.plateauStratas)
            MinMaxIntField(label: "Plateau Sharpness", minValue: $minLayer.nested(\.plateauSharpness), maxValue: $maxLayer.nested(\.plateauSharpness), range: TerrainFieldDocLimits.UberLayer.plateauSharpness)
            MinMaxDoubleField(label: "Plateau Region Size", minValue: $minLayer.nested(\.plateauRegionSize), maxValue: $maxLayer.nested(\.plateauRegionSize), range: TerrainFieldDocLimits.UberLayer.plateauRegionSize)
            MinMaxIntField(label: "Seed Offset", minValue: $minLayer.nested(\.seedOffset), maxValue: $maxLayer.nested(\.seedOffset), range: TerrainFieldDocLimits.UberLayer.seedOffset)
            MinMaxDoubleField(label: "Tile Blend Meters", minValue: $minLayer.nested(\.tileBlendMeters), maxValue: $maxLayer.nested(\.tileBlendMeters), range: TerrainFieldDocLimits.UberLayer.tileBlendMeters)
        }
    }
}

struct UberDataEditorContent: View {
    @Binding var minData: TkNoiseUberData
    @Binding var maxData: TkNoiseUberData
    let globalMin: TkNoiseUberData
    let globalMax: TkNoiseUberData

    var body: some View {
        Group {
            SectionActionBar(
                minValue: $minData,
                maxValue: $maxData,
                applyGlobalMin: { TerrainEditorOperations.applyGlobalMin(to: &$0, from: globalMin) },
                applyGlobalMax: { TerrainEditorOperations.applyGlobalMax(to: &$0, from: globalMax) },
                randomize: { min, max in
                    TerrainEditorOperations.randomizeUberData(
                        min: &min,
                        max: &max,
                        refMin: globalMin,
                        refMax: globalMax
                    )
                }
            )
            MinMaxIntField(label: "Octaves", minValue: $minData.nested(\.octaves), maxValue: $maxData.nested(\.octaves), range: TerrainFieldDocLimits.UberData.octaves)
            MinMaxDoubleField(label: "Slope Gain", minValue: $minData.nested(\.slopeGain), maxValue: $maxData.nested(\.slopeGain), range: TerrainFieldDocLimits.UberData.slopeGain)
            MinMaxDoubleField(label: "Slope Bias", minValue: $minData.nested(\.slopeBias), maxValue: $maxData.nested(\.slopeBias), range: TerrainFieldDocLimits.UberData.slopeBias)
            MinMaxDoubleField(label: "Sharp To Round Features", minValue: $minData.nested(\.sharpToRoundFeatures), maxValue: $maxData.nested(\.sharpToRoundFeatures), range: TerrainFieldDocLimits.UberData.sharpToRoundFeatures)
            MinMaxDoubleField(label: "Amplify Features", minValue: $minData.nested(\.amplifyFeatures), maxValue: $maxData.nested(\.amplifyFeatures), range: TerrainFieldDocLimits.UberData.amplifyFeatures)
            MinMaxDoubleField(label: "Perturb Features", minValue: $minData.nested(\.perturbFeatures), maxValue: $maxData.nested(\.perturbFeatures), range: TerrainFieldDocLimits.UberData.perturbFeatures)
            MinMaxDoubleField(label: "Altitude Erosion", minValue: $minData.nested(\.altitudeErosion), maxValue: $maxData.nested(\.altitudeErosion), range: TerrainFieldDocLimits.UberData.altitudeErosion)
            MinMaxDoubleField(label: "Ridge Erosion", minValue: $minData.nested(\.ridgeErosion), maxValue: $maxData.nested(\.ridgeErosion), range: TerrainFieldDocLimits.UberData.ridgeErosion)
            MinMaxDoubleField(label: "Slope Erosion", minValue: $minData.nested(\.slopeErosion), maxValue: $maxData.nested(\.slopeErosion), range: TerrainFieldDocLimits.UberData.slopeErosion)
            MinMaxDoubleField(label: "Lacunarity", minValue: $minData.nested(\.lacunarity), maxValue: $maxData.nested(\.lacunarity), range: TerrainFieldDocLimits.UberData.lacunarity)
            MinMaxDoubleField(label: "Gain", minValue: $minData.nested(\.gain), maxValue: $maxData.nested(\.gain), range: TerrainFieldDocLimits.UberData.gain)
            MinMaxDoubleField(label: "Remap From Min", minValue: $minData.nested(\.remapFromMin), maxValue: $maxData.nested(\.remapFromMin), range: TerrainFieldDocLimits.UberData.remapFromMin)
            MinMaxDoubleField(label: "Remap From Max", minValue: $minData.nested(\.remapFromMax), maxValue: $maxData.nested(\.remapFromMax), range: TerrainFieldDocLimits.UberData.remapFromMax)
            MinMaxDoubleField(label: "Remap To Min", minValue: $minData.nested(\.remapToMin), maxValue: $maxData.nested(\.remapToMin), range: TerrainFieldDocLimits.UberData.remapToMin)
            MinMaxDoubleField(label: "Remap To Max", minValue: $minData.nested(\.remapToMax), maxValue: $maxData.nested(\.remapToMax), range: TerrainFieldDocLimits.UberData.remapToMax)
            MinMaxEnumField(label: "Debug Noise Type", minValue: $minData.nested(\.debugNoiseType), maxValue: $maxData.nested(\.debugNoiseType))
        }
    }
}

// MARK: - Grid Layer

struct GridLayerFormEditor: View {
    let title: String
    @Binding var minLayer: TkNoiseGridData
    @Binding var maxLayer: TkNoiseGridData
    let globalMin: TkNoiseGridData
    let globalMax: TkNoiseGridData

    var body: some View {
        Form {
            GridLayerEditorContent(
                title: title,
                minLayer: $minLayer,
                maxLayer: $maxLayer,
                globalMin: globalMin,
                globalMax: globalMax
            )
        }
        .formStyle(.grouped)
        .terrainScrollEdgeEffect()
    }
}

struct GridLayerEditorContent: View {
    let title: String
    @Binding var minLayer: TkNoiseGridData
    @Binding var maxLayer: TkNoiseGridData
    let globalMin: TkNoiseGridData
    let globalMax: TkNoiseGridData

    // Heavy/advanced sub-sections are collapsed by default. Collapsed Form sections aren't
    // realized, so the Grid tab keeps far fewer live controls on screen — which is what
    // makes two-finger scrolling smooth (fewer controls to hit-test under the pointer).
    @State private var showTurbulence = false
    @State private var showSuperFormula1 = false
    @State private var showSuperFormula2 = false
    @State private var showSuperPrimitive = false

    var body: some View {
        Section {
            SectionActionBar(
                minValue: $minLayer,
                maxValue: $maxLayer,
                applyGlobalMin: { TerrainEditorOperations.applyGlobalMin(to: &$0, from: globalMin) },
                applyGlobalMax: { TerrainEditorOperations.applyGlobalMax(to: &$0, from: globalMax) },
                randomize: { min, max in
                    TerrainEditorOperations.randomizeGrid(
                        min: &min,
                        max: &max,
                        refMin: globalMin,
                        refMax: globalMax
                    )
                }
            )

            MinMaxBoolField(label: "Active", minValue: $minLayer.nested(\.active), maxValue: $maxLayer.nested(\.active))
            MinMaxIntField(label: "Maximum LOD", minValue: $minLayer.nested(\.maximumLOD), maxValue: $maxLayer.nested(\.maximumLOD), range: TerrainFieldDocLimits.Grid.maximumLOD)
            MinMaxBoolField(label: "Subtract", minValue: $minLayer.nested(\.subtract), maxValue: $maxLayer.nested(\.subtract))
            MinMaxBoolField(label: "Swap ZY", minValue: $minLayer.nested(\.swapZY), maxValue: $maxLayer.nested(\.swapZY))
            MinMaxBoolField(label: "Hemisphere", minValue: $minLayer.nested(\.hemisphere), maxValue: $maxLayer.nested(\.hemisphere))
            MinMaxEnumField(label: "Voxel Type", minValue: $minLayer.nested(\.voxelType).nested(\.noiseVoxelType), maxValue: $maxLayer.nested(\.voxelType).nested(\.noiseVoxelType))
            MinMaxEnumField(label: "Noise Grid Type", minValue: $minLayer.nested(\.noiseGridType), maxValue: $maxLayer.nested(\.noiseGridType))
            MinMaxDoubleField(label: "Min Width", minValue: $minLayer.nested(\.minWidth), maxValue: $maxLayer.nested(\.minWidth), range: TerrainFieldDocLimits.Grid.minWidth)
            MinMaxDoubleField(label: "Max Width", minValue: $minLayer.nested(\.maxWidth), maxValue: $maxLayer.nested(\.maxWidth), range: TerrainFieldDocLimits.Grid.maxWidth)
            MinMaxDoubleField(label: "Min Height", minValue: $minLayer.nested(\.minHeight), maxValue: $maxLayer.nested(\.minHeight), range: TerrainFieldDocLimits.Grid.minHeight)
            MinMaxDoubleField(label: "Max Height", minValue: $minLayer.nested(\.maxHeight), maxValue: $maxLayer.nested(\.maxHeight), range: TerrainFieldDocLimits.Grid.maxHeight)
            MinMaxDoubleField(label: "Min Height Offset", minValue: $minLayer.nested(\.minHeightOffset), maxValue: $maxLayer.nested(\.minHeightOffset), range: TerrainFieldDocLimits.Grid.minHeightOffset)
            MinMaxDoubleField(label: "Max Height Offset", minValue: $minLayer.nested(\.maxHeightOffset), maxValue: $maxLayer.nested(\.maxHeightOffset), range: TerrainFieldDocLimits.Grid.maxHeightOffset)
            MinMaxDoubleField(label: "Height Offset", minValue: $minLayer.nested(\.heightOffset), maxValue: $maxLayer.nested(\.heightOffset), range: TerrainFieldDocLimits.Grid.heightOffset)
            MinMaxEnumField(label: "Offset", minValue: $minLayer.nested(\.offset).nested(\.offsetType), maxValue: $maxLayer.nested(\.offset).nested(\.offsetType))
            MinMaxDoubleField(label: "Region Ratio", minValue: $minLayer.nested(\.regionRatio), maxValue: $maxLayer.nested(\.regionRatio), range: TerrainFieldDocLimits.Grid.regionRatio)
            MinMaxDoubleField(label: "Region Scale", minValue: $minLayer.nested(\.regionScale), maxValue: $maxLayer.nested(\.regionScale), range: TerrainFieldDocLimits.Grid.regionScale)
        }

        Section("Turbulence Noise Layer", isExpanded: $showTurbulence) {
            UberLayerEditorContent(
                title: "Turbulence",
                minLayer: $minLayer.nested(\.turbulenceNoiseLayer),
                maxLayer: $maxLayer.nested(\.turbulenceNoiseLayer),
                globalMin: globalMin.turbulenceNoiseLayer,
                globalMax: globalMax.turbulenceNoiseLayer
            )
        }

        Section("Orientation") {
            MinMaxDoubleField(label: "Yaw", minValue: $minLayer.nested(\.yaw), maxValue: $maxLayer.nested(\.yaw), range: TerrainFieldDocLimits.Grid.yaw)
            MinMaxDoubleField(label: "Pitch", minValue: $minLayer.nested(\.pitch), maxValue: $maxLayer.nested(\.pitch), range: TerrainFieldDocLimits.Grid.pitch)
            MinMaxDoubleField(label: "Roll", minValue: $minLayer.nested(\.roll), maxValue: $maxLayer.nested(\.roll), range: TerrainFieldDocLimits.Grid.roll)
            MinMaxDoubleField(label: "Vary Yaw", minValue: $minLayer.nested(\.varyYaw), maxValue: $maxLayer.nested(\.varyYaw), range: TerrainFieldDocLimits.Grid.varyYaw)
            MinMaxDoubleField(label: "Vary Pitch", minValue: $minLayer.nested(\.varyPitch), maxValue: $maxLayer.nested(\.varyPitch), range: TerrainFieldDocLimits.Grid.varyPitch)
            MinMaxDoubleField(label: "Vary Roll", minValue: $minLayer.nested(\.varyRoll), maxValue: $maxLayer.nested(\.varyRoll), range: TerrainFieldDocLimits.Grid.varyRoll)
            MinMaxDoubleField(label: "Smooth Radius", minValue: $minLayer.nested(\.smoothRadius), maxValue: $maxLayer.nested(\.smoothRadius), range: TerrainFieldDocLimits.Grid.smoothRadius)
            MinMaxIntField(label: "Seed Offset", minValue: $minLayer.nested(\.seedOffset), maxValue: $maxLayer.nested(\.seedOffset), range: aggIntRange(globalMin.seedOffset, globalMax.seedOffset))
            MinMaxDoubleField(label: "Random Primitive", minValue: $minLayer.nested(\.randomPrimitive), maxValue: $maxLayer.nested(\.randomPrimitive), range: TerrainFieldDocLimits.Grid.randomPrimitive)
            MinMaxDoubleField(label: "Tile Blend Meters", minValue: $minLayer.nested(\.tileBlendMeters), maxValue: $maxLayer.nested(\.tileBlendMeters), range: TerrainFieldDocLimits.Grid.tileBlendMeters)
        }

        Section("Super Formula 1", isExpanded: $showSuperFormula1) {
            SuperFormulaEditorContent(title: "Super Formula 1", minData: $minLayer.nested(\.superFormula1), maxData: $maxLayer.nested(\.superFormula1), globalMin: globalMin.superFormula1, globalMax: globalMax.superFormula1)
        }

        Section("Super Formula 2", isExpanded: $showSuperFormula2) {
            SuperFormulaEditorContent(title: "Super Formula 2", minData: $minLayer.nested(\.superFormula2), maxData: $maxLayer.nested(\.superFormula2), globalMin: globalMin.superFormula2, globalMax: globalMax.superFormula2)
        }

        Section("Super Primitive", isExpanded: $showSuperPrimitive) {
            SuperPrimitiveEditorContent(minData: $minLayer.nested(\.superPrimitive), maxData: $maxLayer.nested(\.superPrimitive), globalMin: globalMin.superPrimitive, globalMax: globalMax.superPrimitive)
        }
    }

    private func aggIntRange(_ lo: Int, _ hi: Int) -> ClosedRange<Int> {
        Swift.min(lo, hi)...Swift.max(lo, hi)
    }
}

// MARK: - Features

struct FeatureFormEditor: View {
    let title: String
    @Binding var minFeature: TkNoiseFeatureData
    @Binding var maxFeature: TkNoiseFeatureData
    let globalMin: TkNoiseFeatureData
    let globalMax: TkNoiseFeatureData

    var body: some View {
        Form {
            FeatureEditorContent(
                title: title,
                minFeature: $minFeature,
                maxFeature: $maxFeature,
                globalMin: globalMin,
                globalMax: globalMax
            )
        }
        .formStyle(.grouped)
        .terrainScrollEdgeEffect()
    }
}

struct FeatureEditorContent: View {
    let title: String
    @Binding var minFeature: TkNoiseFeatureData
    @Binding var maxFeature: TkNoiseFeatureData
    let globalMin: TkNoiseFeatureData
    let globalMax: TkNoiseFeatureData

    var body: some View {
        Section {
            SectionActionBar(
                minValue: $minFeature,
                maxValue: $maxFeature,
                applyGlobalMin: { TerrainEditorOperations.applyGlobalMin(to: &$0, from: globalMin) },
                applyGlobalMax: { TerrainEditorOperations.applyGlobalMax(to: &$0, from: globalMax) },
                randomize: { min, max in
                    TerrainEditorOperations.randomizeFeature(
                        min: &min,
                        max: &max,
                        refMin: globalMin,
                        refMax: globalMax
                    )
                }
            )

            MinMaxBoolField(label: "Active", minValue: $minFeature.nested(\.active), maxValue: $maxFeature.nested(\.active))
            MinMaxIntField(label: "Maximum LOD", minValue: $minFeature.nested(\.maximumLOD), maxValue: $maxFeature.nested(\.maximumLOD), range: aggIntRange(globalMin.maximumLOD, globalMax.maximumLOD))
            MinMaxBoolField(label: "Subtract", minValue: $minFeature.nested(\.subtract), maxValue: $maxFeature.nested(\.subtract))
            MinMaxBoolField(label: "Trench", minValue: $minFeature.nested(\.trench), maxValue: $maxFeature.nested(\.trench))
            MinMaxEnumField(label: "Voxel Type", minValue: $minFeature.nested(\.voxelType).nested(\.noiseVoxelType), maxValue: $maxFeature.nested(\.voxelType).nested(\.noiseVoxelType))
            MinMaxEnumField(label: "Feature Type", minValue: $minFeature.nested(\.featureType), maxValue: $maxFeature.nested(\.featureType))
            MinMaxDoubleField(label: "Width", minValue: $minFeature.nested(\.width), maxValue: $maxFeature.nested(\.width), range: TerrainFieldDocLimits.Feature.width)
            MinMaxDoubleField(label: "Height", minValue: $minFeature.nested(\.height), maxValue: $maxFeature.nested(\.height), range: TerrainFieldDocLimits.Feature.height)
            MinMaxIntField(label: "Octaves", minValue: $minFeature.nested(\.octaves), maxValue: $maxFeature.nested(\.octaves), range: aggIntRange(globalMin.octaves, globalMax.octaves))
            MinMaxDoubleField(label: "Region Size", minValue: $minFeature.nested(\.regionSize), maxValue: $maxFeature.nested(\.regionSize), range: TerrainFieldDocLimits.Feature.regionSize)
            MinMaxDoubleField(label: "Ratio", minValue: $minFeature.nested(\.ratio), maxValue: $maxFeature.nested(\.ratio), range: TerrainFieldDocLimits.Feature.ratio)
            MinMaxDoubleField(label: "Height Variance Amplitude", minValue: $minFeature.nested(\.heightVarianceAmplitude), maxValue: $maxFeature.nested(\.heightVarianceAmplitude), range: TerrainFieldDocLimits.Feature.heightVarianceAmplitude)
            MinMaxDoubleField(label: "Height Variance Frequency", minValue: $minFeature.nested(\.heightVarianceFrequency), maxValue: $maxFeature.nested(\.heightVarianceFrequency), range: TerrainFieldDocLimits.Feature.heightVarianceFrequency)
            MinMaxDoubleField(label: "Height Offset", minValue: $minFeature.nested(\.heightOffset), maxValue: $maxFeature.nested(\.heightOffset), range: TerrainFieldDocLimits.Feature.heightOffset)
            MinMaxEnumField(label: "Offset", minValue: $minFeature.nested(\.offset).nested(\.offsetType), maxValue: $maxFeature.nested(\.offset).nested(\.offsetType))
            MinMaxDoubleField(label: "Smooth Radius", minValue: $minFeature.nested(\.smoothRadius), maxValue: $maxFeature.nested(\.smoothRadius), range: aggRange(globalMin.smoothRadius, globalMax.smoothRadius))
            MinMaxIntField(label: "Seed Offset", minValue: $minFeature.nested(\.seedOffset), maxValue: $maxFeature.nested(\.seedOffset), range: aggIntRange(globalMin.seedOffset, globalMax.seedOffset))
            MinMaxDoubleField(label: "Tile Blend Meters", minValue: $minFeature.nested(\.tileBlendMeters), maxValue: $maxFeature.nested(\.tileBlendMeters), range: TerrainFieldDocLimits.Feature.tileBlendMeters)
        }
    }

    private func aggRange(_ lo: Double, _ hi: Double) -> ClosedRange<Double> {
        Swift.min(lo, hi)...Swift.max(lo, hi)
    }

    private func aggIntRange(_ lo: Int, _ hi: Int) -> ClosedRange<Int> {
        Swift.min(lo, hi)...Swift.max(lo, hi)
    }
}

// MARK: - Super Formula / Primitive

struct SuperFormulaEditorContent: View {
    let title: String
    @Binding var minData: TkNoiseSuperFormulaData
    @Binding var maxData: TkNoiseSuperFormulaData
    let globalMin: TkNoiseSuperFormulaData
    let globalMax: TkNoiseSuperFormulaData

    var body: some View {
        Group {
            SectionActionBar(
                minValue: $minData,
                maxValue: $maxData,
                applyGlobalMin: { TerrainEditorOperations.applyGlobalMin(to: &$0, from: globalMin) },
                applyGlobalMax: { TerrainEditorOperations.applyGlobalMax(to: &$0, from: globalMax) },
                randomize: { min, max in
                    TerrainEditorOperations.randomizeSuperFormula(
                        min: &min,
                        max: &max,
                        refMin: globalMin,
                        refMax: globalMax
                    )
                }
            )
            MinMaxDoubleField(label: "\(title) Form M", minValue: $minData.nested(\.formM), maxValue: $maxData.nested(\.formM), range: TerrainFieldDocLimits.SuperFormula.formM)
            MinMaxDoubleField(label: "\(title) Form N1", minValue: $minData.nested(\.formN1), maxValue: $maxData.nested(\.formN1), range: TerrainFieldDocLimits.SuperFormula.formN1)
            MinMaxDoubleField(label: "\(title) Form N2", minValue: $minData.nested(\.formN2), maxValue: $maxData.nested(\.formN2), range: TerrainFieldDocLimits.SuperFormula.formN2)
            MinMaxDoubleField(label: "\(title) Form N3", minValue: $minData.nested(\.formN3), maxValue: $maxData.nested(\.formN3), range: TerrainFieldDocLimits.SuperFormula.formN3)
        }
    }
}

struct SuperPrimitiveEditorContent: View {
    @Binding var minData: TkNoiseSuperPrimitiveData
    @Binding var maxData: TkNoiseSuperPrimitiveData
    let globalMin: TkNoiseSuperPrimitiveData
    let globalMax: TkNoiseSuperPrimitiveData

    var body: some View {
        Group {
            SectionActionBar(
                minValue: $minData,
                maxValue: $maxData,
                applyGlobalMin: { TerrainEditorOperations.applyGlobalMin(to: &$0, from: globalMin) },
                applyGlobalMax: { TerrainEditorOperations.applyGlobalMax(to: &$0, from: globalMax) },
                randomize: { min, max in
                    TerrainEditorOperations.randomizeSuperPrimitive(
                        min: &min,
                        max: &max,
                        refMin: globalMin,
                        refMax: globalMax
                    )
                }
            )
            MinMaxDoubleField(label: "Width", minValue: $minData.nested(\.width), maxValue: $maxData.nested(\.width), range: TerrainFieldDocLimits.SuperPrimitive.width)
            MinMaxDoubleField(label: "Height", minValue: $minData.nested(\.height), maxValue: $maxData.nested(\.height), range: TerrainFieldDocLimits.SuperPrimitive.height)
            MinMaxDoubleField(label: "Depth", minValue: $minData.nested(\.depth), maxValue: $maxData.nested(\.depth), range: TerrainFieldDocLimits.SuperPrimitive.depth)
            MinMaxDoubleField(label: "Thickness", minValue: $minData.nested(\.thickness), maxValue: $maxData.nested(\.thickness), range: TerrainFieldDocLimits.SuperPrimitive.thickness)
            MinMaxDoubleField(label: "Corner Radius XY", minValue: $minData.nested(\.cornerRadiusXY), maxValue: $maxData.nested(\.cornerRadiusXY), range: TerrainFieldDocLimits.SuperPrimitive.cornerRadiusXY)
            MinMaxDoubleField(label: "Corner Radius Z", minValue: $minData.nested(\.cornerRadiusZ), maxValue: $maxData.nested(\.cornerRadiusZ), range: TerrainFieldDocLimits.SuperPrimitive.cornerRadiusZ)
            MinMaxDoubleField(label: "Bottom Radius Offset", minValue: $minData.nested(\.bottomRadiusOffset), maxValue: $maxData.nested(\.bottomRadiusOffset), range: TerrainFieldDocLimits.SuperPrimitive.bottomRadiusOffset)
        }
    }
}