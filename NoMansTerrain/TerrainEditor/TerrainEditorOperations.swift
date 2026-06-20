import Foundation

enum TerrainEditorOperations {
    // MARK: - Apply global limits

    static func applyGlobalMin(to minData: inout TkVoxelGeneratorData, from global: TkVoxelGeneratorData) {
        minData = global
    }

    static func applyGlobalMax(to maxData: inout TkVoxelGeneratorData, from global: TkVoxelGeneratorData) {
        maxData = global
    }

    static func applyGlobalMin(to minLayer: inout TkNoiseUberLayerData, from global: TkNoiseUberLayerData) {
        minLayer = global
    }

    static func applyGlobalMax(to maxLayer: inout TkNoiseUberLayerData, from global: TkNoiseUberLayerData) {
        maxLayer = global
    }

    static func applyGlobalMin(to minData: inout TkNoiseUberData, from global: TkNoiseUberData) {
        minData = global
    }

    static func applyGlobalMax(to maxData: inout TkNoiseUberData, from global: TkNoiseUberData) {
        maxData = global
    }

    static func applyGlobalMin(to minData: inout TkNoiseGridData, from global: TkNoiseGridData) {
        minData = global
    }

    static func applyGlobalMax(to maxData: inout TkNoiseGridData, from global: TkNoiseGridData) {
        maxData = global
    }

    static func applyGlobalMin(to minData: inout TkNoiseFeatureData, from global: TkNoiseFeatureData) {
        minData = global
    }

    static func applyGlobalMax(to maxData: inout TkNoiseFeatureData, from global: TkNoiseFeatureData) {
        maxData = global
    }

    static func applyGlobalMin(to minData: inout TkNoiseSuperFormulaData, from global: TkNoiseSuperFormulaData) {
        minData = global
    }

    static func applyGlobalMax(to maxData: inout TkNoiseSuperFormulaData, from global: TkNoiseSuperFormulaData) {
        maxData = global
    }

    static func applyGlobalMin(to minData: inout TkNoiseSuperPrimitiveData, from global: TkNoiseSuperPrimitiveData) {
        minData = global
    }

    static func applyGlobalMax(to maxData: inout TkNoiseSuperPrimitiveData, from global: TkNoiseSuperPrimitiveData) {
        maxData = global
    }

    // MARK: - Activate all

    /// Turns on every `active` toggle in a terrain file: all noise layers, grid
    /// layers (including their turbulence layer), features, and cave features.
    static func activateAll(_ data: inout TkVoxelGeneratorData) {
        let noiseLayers: [WritableKeyPath<NoiseLayers, TkNoiseUberLayerData>] = [
            \.base, \.hill, \.mountain, \.rock, \.underWater, \.texture, \.elevation, \.continent
        ]
        for keyPath in noiseLayers {
            data.noiseLayers[keyPath: keyPath].active = true
        }

        let gridLayers: [WritableKeyPath<GridLayers, TkNoiseGridData>] = [
            \.small, \.large,
            \.resourcesHeridium, \.resourcesIridium, \.resourcesCopper, \.resourcesNickel,
            \.resourcesAluminium, \.resourcesGold, \.resourcesEmeril
        ]
        for keyPath in gridLayers {
            data.gridLayers[keyPath: keyPath].active = true
            data.gridLayers[keyPath: keyPath].turbulenceNoiseLayer.active = true
        }

        let features: [WritableKeyPath<Features, TkNoiseFeatureData>] = [
            \.river, \.crater, \.arches, \.archesSmall, \.blobs, \.blobsSmall, \.substance
        ]
        for keyPath in features {
            data.features[keyPath: keyPath].active = true
        }

        data.caves.underground.mouth.active = true
        data.caves.underground.tunnel.active = true
    }

    // MARK: - Documented limits (safe defaults & absolute bounds)

    /// How each documented field's min/max are set by `applyDocumentedLimits`.
    private enum BoundMode {
        /// Widen toward the documented limit: min = lower of (current, docLower),
        /// max = higher of (current, docUpper). Keeps observed values that are even wider.
        case widen
        /// Snap to the documented limit exactly: min = docLower, max = docUpper.
        case absolute
    }

    /// Widens an aggregated min/max pair so each documented field spans the *wider* of
    /// the aggregated envelope and its documented limit. Call with `min` seeded from the
    /// bundle's aggregated globalMin and `max` from globalMax; undocumented fields (and all
    /// enums, bools, seeds) are left at the aggregated values already present.
    static func applySafeDefaults(min: inout TkVoxelGeneratorData, max: inout TkVoxelGeneratorData) {
        applyDocumentedLimits(min: &min, max: &max, mode: .widen)
    }

    /// Snaps every documented field to its absolute documented bounds (min = docLower,
    /// max = docUpper). Undocumented fields are left at the values already present.
    static func applyAbsoluteBounds(min: inout TkVoxelGeneratorData, max: inout TkVoxelGeneratorData) {
        applyDocumentedLimits(min: &min, max: &max, mode: .absolute)
    }

    private static func applyDocumentedLimits(min: inout TkVoxelGeneratorData, max: inout TkVoxelGeneratorData, mode: BoundMode) {
        // Root scalars (seaLevel, beachHeight, …) have no documented limits — leave them.

        let noiseLayers: [WritableKeyPath<NoiseLayers, TkNoiseUberLayerData>] = [
            \.base, \.hill, \.mountain, \.rock, \.underWater, \.texture, \.elevation, \.continent
        ]
        for keyPath in noiseLayers {
            applyDocUberLayer(min: &min.noiseLayers[keyPath: keyPath], max: &max.noiseLayers[keyPath: keyPath], mode: mode)
        }

        let gridLayers: [WritableKeyPath<GridLayers, TkNoiseGridData>] = [
            \.small, \.large,
            \.resourcesHeridium, \.resourcesIridium, \.resourcesCopper, \.resourcesNickel,
            \.resourcesAluminium, \.resourcesGold, \.resourcesEmeril
        ]
        for keyPath in gridLayers {
            applyDocGrid(min: &min.gridLayers[keyPath: keyPath], max: &max.gridLayers[keyPath: keyPath], mode: mode)
        }

        let features: [WritableKeyPath<Features, TkNoiseFeatureData>] = [
            \.river, \.crater, \.arches, \.archesSmall, \.blobs, \.blobsSmall, \.substance
        ]
        for keyPath in features {
            applyDocFeature(min: &min.features[keyPath: keyPath], max: &max.features[keyPath: keyPath], mode: mode)
        }

        applyDocFeature(min: &min.caves.underground.mouth, max: &max.caves.underground.mouth, mode: mode)
        applyDocFeature(min: &min.caves.underground.tunnel, max: &max.caves.underground.tunnel, mode: mode)
    }

    private static func applyDocUberData(min: inout TkNoiseUberData, max: inout TkNoiseUberData, mode: BoundMode) {
        bound(&min.octaves, &max.octaves, TerrainFieldDocLimits.UberData.octaves, mode)
        bound(&min.slopeGain, &max.slopeGain, TerrainFieldDocLimits.UberData.slopeGain, mode)
        bound(&min.slopeBias, &max.slopeBias, TerrainFieldDocLimits.UberData.slopeBias, mode)
        bound(&min.sharpToRoundFeatures, &max.sharpToRoundFeatures, TerrainFieldDocLimits.UberData.sharpToRoundFeatures, mode)
        bound(&min.amplifyFeatures, &max.amplifyFeatures, TerrainFieldDocLimits.UberData.amplifyFeatures, mode)
        bound(&min.perturbFeatures, &max.perturbFeatures, TerrainFieldDocLimits.UberData.perturbFeatures, mode)
        bound(&min.altitudeErosion, &max.altitudeErosion, TerrainFieldDocLimits.UberData.altitudeErosion, mode)
        bound(&min.ridgeErosion, &max.ridgeErosion, TerrainFieldDocLimits.UberData.ridgeErosion, mode)
        bound(&min.slopeErosion, &max.slopeErosion, TerrainFieldDocLimits.UberData.slopeErosion, mode)
        bound(&min.lacunarity, &max.lacunarity, TerrainFieldDocLimits.UberData.lacunarity, mode)
        bound(&min.gain, &max.gain, TerrainFieldDocLimits.UberData.gain, mode)
        bound(&min.remapFromMin, &max.remapFromMin, TerrainFieldDocLimits.UberData.remapFromMin, mode)
        bound(&min.remapFromMax, &max.remapFromMax, TerrainFieldDocLimits.UberData.remapFromMax, mode)
        bound(&min.remapToMin, &max.remapToMin, TerrainFieldDocLimits.UberData.remapToMin, mode)
        bound(&min.remapToMax, &max.remapToMax, TerrainFieldDocLimits.UberData.remapToMax, mode)
    }

    private static func applyDocUberLayer(min: inout TkNoiseUberLayerData, max: inout TkNoiseUberLayerData, mode: BoundMode) {
        applyDocUberData(min: &min.noiseData, max: &max.noiseData, mode: mode)
        bound(&min.maximumLOD, &max.maximumLOD, TerrainFieldDocLimits.UberLayer.maximumLOD, mode)
        bound(&min.height, &max.height, TerrainFieldDocLimits.UberLayer.height, mode)
        bound(&min.width, &max.width, TerrainFieldDocLimits.UberLayer.width, mode)
        bound(&min.regionRatio, &max.regionRatio, TerrainFieldDocLimits.UberLayer.regionRatio, mode)
        bound(&min.regionScale, &max.regionScale, TerrainFieldDocLimits.UberLayer.regionScale, mode)
        bound(&min.regionGain, &max.regionGain, TerrainFieldDocLimits.UberLayer.regionGain, mode)
        bound(&min.smoothRadius, &max.smoothRadius, TerrainFieldDocLimits.UberLayer.smoothRadius, mode)
        bound(&min.heightOffset, &max.heightOffset, TerrainFieldDocLimits.UberLayer.heightOffset, mode)
        bound(&min.plateauStratas, &max.plateauStratas, TerrainFieldDocLimits.UberLayer.plateauStratas, mode)
        bound(&min.plateauSharpness, &max.plateauSharpness, TerrainFieldDocLimits.UberLayer.plateauSharpness, mode)
        bound(&min.plateauRegionSize, &max.plateauRegionSize, TerrainFieldDocLimits.UberLayer.plateauRegionSize, mode)
        bound(&min.seedOffset, &max.seedOffset, TerrainFieldDocLimits.UberLayer.seedOffset, mode)
        bound(&min.tileBlendMeters, &max.tileBlendMeters, TerrainFieldDocLimits.UberLayer.tileBlendMeters, mode)
    }

    private static func applyDocGrid(min: inout TkNoiseGridData, max: inout TkNoiseGridData, mode: BoundMode) {
        bound(&min.maximumLOD, &max.maximumLOD, TerrainFieldDocLimits.Grid.maximumLOD, mode)
        bound(&min.minWidth, &max.minWidth, TerrainFieldDocLimits.Grid.minWidth, mode)
        bound(&min.maxWidth, &max.maxWidth, TerrainFieldDocLimits.Grid.maxWidth, mode)
        bound(&min.minHeight, &max.minHeight, TerrainFieldDocLimits.Grid.minHeight, mode)
        bound(&min.maxHeight, &max.maxHeight, TerrainFieldDocLimits.Grid.maxHeight, mode)
        bound(&min.minHeightOffset, &max.minHeightOffset, TerrainFieldDocLimits.Grid.minHeightOffset, mode)
        bound(&min.maxHeightOffset, &max.maxHeightOffset, TerrainFieldDocLimits.Grid.maxHeightOffset, mode)
        bound(&min.heightOffset, &max.heightOffset, TerrainFieldDocLimits.Grid.heightOffset, mode)
        bound(&min.regionRatio, &max.regionRatio, TerrainFieldDocLimits.Grid.regionRatio, mode)
        bound(&min.regionScale, &max.regionScale, TerrainFieldDocLimits.Grid.regionScale, mode)
        bound(&min.yaw, &max.yaw, TerrainFieldDocLimits.Grid.yaw, mode)
        bound(&min.pitch, &max.pitch, TerrainFieldDocLimits.Grid.pitch, mode)
        bound(&min.roll, &max.roll, TerrainFieldDocLimits.Grid.roll, mode)
        bound(&min.varyYaw, &max.varyYaw, TerrainFieldDocLimits.Grid.varyYaw, mode)
        bound(&min.varyPitch, &max.varyPitch, TerrainFieldDocLimits.Grid.varyPitch, mode)
        bound(&min.varyRoll, &max.varyRoll, TerrainFieldDocLimits.Grid.varyRoll, mode)
        bound(&min.smoothRadius, &max.smoothRadius, TerrainFieldDocLimits.Grid.smoothRadius, mode)
        bound(&min.randomPrimitive, &max.randomPrimitive, TerrainFieldDocLimits.Grid.randomPrimitive, mode)
        bound(&min.tileBlendMeters, &max.tileBlendMeters, TerrainFieldDocLimits.Grid.tileBlendMeters, mode)
        applyDocUberLayer(min: &min.turbulenceNoiseLayer, max: &max.turbulenceNoiseLayer, mode: mode)
        applyDocSuperFormula(min: &min.superFormula1, max: &max.superFormula1, mode: mode)
        applyDocSuperFormula(min: &min.superFormula2, max: &max.superFormula2, mode: mode)
        applyDocSuperPrimitive(min: &min.superPrimitive, max: &max.superPrimitive, mode: mode)
    }

    private static func applyDocFeature(min: inout TkNoiseFeatureData, max: inout TkNoiseFeatureData, mode: BoundMode) {
        bound(&min.width, &max.width, TerrainFieldDocLimits.Feature.width, mode)
        bound(&min.height, &max.height, TerrainFieldDocLimits.Feature.height, mode)
        bound(&min.regionSize, &max.regionSize, TerrainFieldDocLimits.Feature.regionSize, mode)
        bound(&min.ratio, &max.ratio, TerrainFieldDocLimits.Feature.ratio, mode)
        bound(&min.heightVarianceAmplitude, &max.heightVarianceAmplitude, TerrainFieldDocLimits.Feature.heightVarianceAmplitude, mode)
        bound(&min.heightVarianceFrequency, &max.heightVarianceFrequency, TerrainFieldDocLimits.Feature.heightVarianceFrequency, mode)
        bound(&min.heightOffset, &max.heightOffset, TerrainFieldDocLimits.Feature.heightOffset, mode)
        bound(&min.tileBlendMeters, &max.tileBlendMeters, TerrainFieldDocLimits.Feature.tileBlendMeters, mode)
    }

    private static func applyDocSuperFormula(min: inout TkNoiseSuperFormulaData, max: inout TkNoiseSuperFormulaData, mode: BoundMode) {
        bound(&min.formM, &max.formM, TerrainFieldDocLimits.SuperFormula.formM, mode)
        bound(&min.formN1, &max.formN1, TerrainFieldDocLimits.SuperFormula.formN1, mode)
        bound(&min.formN2, &max.formN2, TerrainFieldDocLimits.SuperFormula.formN2, mode)
        bound(&min.formN3, &max.formN3, TerrainFieldDocLimits.SuperFormula.formN3, mode)
    }

    private static func applyDocSuperPrimitive(min: inout TkNoiseSuperPrimitiveData, max: inout TkNoiseSuperPrimitiveData, mode: BoundMode) {
        bound(&min.width, &max.width, TerrainFieldDocLimits.SuperPrimitive.width, mode)
        bound(&min.height, &max.height, TerrainFieldDocLimits.SuperPrimitive.height, mode)
        bound(&min.depth, &max.depth, TerrainFieldDocLimits.SuperPrimitive.depth, mode)
        bound(&min.thickness, &max.thickness, TerrainFieldDocLimits.SuperPrimitive.thickness, mode)
        bound(&min.cornerRadiusXY, &max.cornerRadiusXY, TerrainFieldDocLimits.SuperPrimitive.cornerRadiusXY, mode)
        bound(&min.cornerRadiusZ, &max.cornerRadiusZ, TerrainFieldDocLimits.SuperPrimitive.cornerRadiusZ, mode)
        bound(&min.bottomRadiusOffset, &max.bottomRadiusOffset, TerrainFieldDocLimits.SuperPrimitive.bottomRadiusOffset, mode)
    }

    private static func bound(_ minValue: inout Double, _ maxValue: inout Double, _ documented: ClosedRange<Double>, _ mode: BoundMode) {
        switch mode {
        case .widen:
            minValue = Swift.min(minValue, documented.lowerBound)
            maxValue = Swift.max(maxValue, documented.upperBound)
        case .absolute:
            minValue = documented.lowerBound
            maxValue = documented.upperBound
        }
    }

    private static func bound(_ minValue: inout Int, _ maxValue: inout Int, _ documented: ClosedRange<Int>, _ mode: BoundMode) {
        switch mode {
        case .widen:
            minValue = Swift.min(minValue, documented.lowerBound)
            maxValue = Swift.max(maxValue, documented.upperBound)
        case .absolute:
            minValue = documented.lowerBound
            maxValue = documented.upperBound
        }
    }

    // MARK: - Randomize

    static func randomizeRootScalars(
        minData: inout TkVoxelGeneratorData,
        maxData: inout TkVoxelGeneratorData,
        refMin: TkVoxelGeneratorData,
        refMax: TkVoxelGeneratorData
    ) {
        randomizeScalars(min: &minData, max: &maxData, refMin: refMin, refMax: refMax)
    }

    static func randomizeRoot(
        minData: inout TkVoxelGeneratorData,
        maxData: inout TkVoxelGeneratorData,
        refMin: TkVoxelGeneratorData,
        refMax: TkVoxelGeneratorData
    ) {
        randomizeScalars(min: &minData, max: &maxData, refMin: refMin, refMax: refMax)
        randomizeNoiseLayers(min: &minData.noiseLayers, max: &maxData.noiseLayers, refMin: refMin.noiseLayers, refMax: refMax.noiseLayers)
        randomizeGridLayers(min: &minData.gridLayers, max: &maxData.gridLayers, refMin: refMin.gridLayers, refMax: refMax.gridLayers)
        randomizeFeatures(min: &minData.features, max: &maxData.features, refMin: refMin.features, refMax: refMax.features)
        randomizeCaves(min: &minData.caves, max: &maxData.caves, refMin: refMin.caves, refMax: refMax.caves)
    }

    static func randomizeUberLayer(
        min: inout TkNoiseUberLayerData,
        max: inout TkNoiseUberLayerData,
        refMin: TkNoiseUberLayerData,
        refMax: TkNoiseUberLayerData
    ) {
        randomizeUberData(min: &min.noiseData, max: &max.noiseData, refMin: refMin.noiseData, refMax: refMax.noiseData)
        randomizeBoolPair(min: &min.active, max: &max.active, refMin: refMin.active, refMax: refMax.active, hasDoc: false)
        randomizeIntPair(min: &min.maximumLOD, max: &max.maximumLOD, range: TerrainFieldDocLimits.UberLayer.maximumLOD, hasDoc: true, refMin: refMin.maximumLOD, refMax: refMax.maximumLOD)
        randomizeBoolPair(min: &min.subtract, max: &max.subtract, refMin: refMin.subtract, refMax: refMax.subtract, hasDoc: false)
        randomizeEnumPair(min: &min.voxelType.noiseVoxelType, max: &max.voxelType.noiseVoxelType, refMin: refMin.voxelType.noiseVoxelType, refMax: refMax.voxelType.noiseVoxelType, hasDoc: false)
        randomizeDoublePair(min: &min.height, max: &max.height, documented: TerrainFieldDocLimits.UberLayer.height, hasDoc: true, refMin: refMin.height, refMax: refMax.height)
        randomizeDoublePair(min: &min.width, max: &max.width, documented: TerrainFieldDocLimits.UberLayer.width, hasDoc: true, refMin: refMin.width, refMax: refMax.width)
        randomizeDoublePair(min: &min.regionRatio, max: &max.regionRatio, documented: TerrainFieldDocLimits.UberLayer.regionRatio, hasDoc: true, refMin: refMin.regionRatio, refMax: refMax.regionRatio)
        randomizeDoublePair(min: &min.regionScale, max: &max.regionScale, documented: TerrainFieldDocLimits.UberLayer.regionScale, hasDoc: true, refMin: refMin.regionScale, refMax: refMax.regionScale)
        randomizeDoublePair(min: &min.regionGain, max: &max.regionGain, documented: TerrainFieldDocLimits.UberLayer.regionGain, hasDoc: true, refMin: refMin.regionGain, refMax: refMax.regionGain)
        randomizeDoublePair(min: &min.smoothRadius, max: &max.smoothRadius, documented: TerrainFieldDocLimits.UberLayer.smoothRadius, hasDoc: true, refMin: refMin.smoothRadius, refMax: refMax.smoothRadius)
        randomizeDoublePair(min: &min.heightOffset, max: &max.heightOffset, documented: TerrainFieldDocLimits.UberLayer.heightOffset, hasDoc: true, refMin: refMin.heightOffset, refMax: refMax.heightOffset)
        randomizeEnumPair(min: &min.offset.offsetType, max: &max.offset.offsetType, refMin: refMin.offset.offsetType, refMax: refMax.offset.offsetType, hasDoc: false)
        randomizeEnumPair(min: &min.waterFade, max: &max.waterFade, refMin: refMin.waterFade, refMax: refMax.waterFade, hasDoc: false)
        randomizeDoublePair(min: &min.plateauStratas, max: &max.plateauStratas, documented: TerrainFieldDocLimits.UberLayer.plateauStratas, hasDoc: true, refMin: refMin.plateauStratas, refMax: refMax.plateauStratas)
        randomizeIntPair(min: &min.plateauSharpness, max: &max.plateauSharpness, range: TerrainFieldDocLimits.UberLayer.plateauSharpness, hasDoc: true, refMin: refMin.plateauSharpness, refMax: refMax.plateauSharpness)
        randomizeDoublePair(min: &min.plateauRegionSize, max: &max.plateauRegionSize, documented: TerrainFieldDocLimits.UberLayer.plateauRegionSize, hasDoc: true, refMin: refMin.plateauRegionSize, refMax: refMax.plateauRegionSize)
        randomizeIntPair(min: &min.seedOffset, max: &max.seedOffset, range: TerrainFieldDocLimits.UberLayer.seedOffset, hasDoc: true, refMin: refMin.seedOffset, refMax: refMax.seedOffset)
        randomizeDoublePair(min: &min.tileBlendMeters, max: &max.tileBlendMeters, documented: TerrainFieldDocLimits.UberLayer.tileBlendMeters, hasDoc: true, refMin: refMin.tileBlendMeters, refMax: refMax.tileBlendMeters)
    }

    static func randomizeUberData(
        min: inout TkNoiseUberData,
        max: inout TkNoiseUberData,
        refMin: TkNoiseUberData,
        refMax: TkNoiseUberData
    ) {
        randomizeIntPair(min: &min.octaves, max: &max.octaves, range: TerrainFieldDocLimits.UberData.octaves, hasDoc: true, refMin: refMin.octaves, refMax: refMax.octaves)
        randomizeDoublePair(min: &min.slopeGain, max: &max.slopeGain, documented: TerrainFieldDocLimits.UberData.slopeGain, hasDoc: true, refMin: refMin.slopeGain, refMax: refMax.slopeGain)
        randomizeDoublePair(min: &min.slopeBias, max: &max.slopeBias, documented: TerrainFieldDocLimits.UberData.slopeBias, hasDoc: true, refMin: refMin.slopeBias, refMax: refMax.slopeBias)
        randomizeDoublePair(min: &min.sharpToRoundFeatures, max: &max.sharpToRoundFeatures, documented: TerrainFieldDocLimits.UberData.sharpToRoundFeatures, hasDoc: true, refMin: refMin.sharpToRoundFeatures, refMax: refMax.sharpToRoundFeatures)
        randomizeDoublePair(min: &min.amplifyFeatures, max: &max.amplifyFeatures, documented: TerrainFieldDocLimits.UberData.amplifyFeatures, hasDoc: true, refMin: refMin.amplifyFeatures, refMax: refMax.amplifyFeatures)
        randomizeDoublePair(min: &min.perturbFeatures, max: &max.perturbFeatures, documented: TerrainFieldDocLimits.UberData.perturbFeatures, hasDoc: true, refMin: refMin.perturbFeatures, refMax: refMax.perturbFeatures)
        randomizeDoublePair(min: &min.altitudeErosion, max: &max.altitudeErosion, documented: TerrainFieldDocLimits.UberData.altitudeErosion, hasDoc: true, refMin: refMin.altitudeErosion, refMax: refMax.altitudeErosion)
        randomizeDoublePair(min: &min.ridgeErosion, max: &max.ridgeErosion, documented: TerrainFieldDocLimits.UberData.ridgeErosion, hasDoc: true, refMin: refMin.ridgeErosion, refMax: refMax.ridgeErosion)
        randomizeDoublePair(min: &min.slopeErosion, max: &max.slopeErosion, documented: TerrainFieldDocLimits.UberData.slopeErosion, hasDoc: true, refMin: refMin.slopeErosion, refMax: refMax.slopeErosion)
        randomizeDoublePair(min: &min.lacunarity, max: &max.lacunarity, documented: TerrainFieldDocLimits.UberData.lacunarity, hasDoc: true, refMin: refMin.lacunarity, refMax: refMax.lacunarity)
        randomizeDoublePair(min: &min.gain, max: &max.gain, documented: TerrainFieldDocLimits.UberData.gain, hasDoc: true, refMin: refMin.gain, refMax: refMax.gain)
        randomizeDoublePair(min: &min.remapFromMin, max: &max.remapFromMin, documented: TerrainFieldDocLimits.UberData.remapFromMin, hasDoc: true, refMin: refMin.remapFromMin, refMax: refMax.remapFromMin)
        randomizeDoublePair(min: &min.remapFromMax, max: &max.remapFromMax, documented: TerrainFieldDocLimits.UberData.remapFromMax, hasDoc: true, refMin: refMin.remapFromMax, refMax: refMax.remapFromMax)
        randomizeDoublePair(min: &min.remapToMin, max: &max.remapToMin, documented: TerrainFieldDocLimits.UberData.remapToMin, hasDoc: true, refMin: refMin.remapToMin, refMax: refMax.remapToMin)
        randomizeDoublePair(min: &min.remapToMax, max: &max.remapToMax, documented: TerrainFieldDocLimits.UberData.remapToMax, hasDoc: true, refMin: refMin.remapToMax, refMax: refMax.remapToMax)
        randomizeEnumPair(min: &min.debugNoiseType, max: &max.debugNoiseType, refMin: refMin.debugNoiseType, refMax: refMax.debugNoiseType, hasDoc: false)
    }

    static func randomizeGrid(
        min: inout TkNoiseGridData,
        max: inout TkNoiseGridData,
        refMin: TkNoiseGridData,
        refMax: TkNoiseGridData
    ) {
        randomizeBoolPair(min: &min.active, max: &max.active, refMin: refMin.active, refMax: refMax.active, hasDoc: false)
        randomizeIntPair(min: &min.maximumLOD, max: &max.maximumLOD, range: TerrainFieldDocLimits.Grid.maximumLOD, hasDoc: true, refMin: refMin.maximumLOD, refMax: refMax.maximumLOD)
        randomizeBoolPair(min: &min.subtract, max: &max.subtract, refMin: refMin.subtract, refMax: refMax.subtract, hasDoc: false)
        randomizeBoolPair(min: &min.swapZY, max: &max.swapZY, refMin: refMin.swapZY, refMax: refMax.swapZY, hasDoc: false)
        randomizeBoolPair(min: &min.hemisphere, max: &max.hemisphere, refMin: refMin.hemisphere, refMax: refMax.hemisphere, hasDoc: false)
        randomizeEnumPair(min: &min.voxelType.noiseVoxelType, max: &max.voxelType.noiseVoxelType, refMin: refMin.voxelType.noiseVoxelType, refMax: refMax.voxelType.noiseVoxelType, hasDoc: false)
        randomizeEnumPair(min: &min.noiseGridType, max: &max.noiseGridType, refMin: refMin.noiseGridType, refMax: refMax.noiseGridType, hasDoc: false)
        randomizeDoublePair(min: &min.minWidth, max: &max.minWidth, documented: TerrainFieldDocLimits.Grid.minWidth, hasDoc: true, refMin: refMin.minWidth, refMax: refMax.minWidth)
        randomizeDoublePair(min: &min.maxWidth, max: &max.maxWidth, documented: TerrainFieldDocLimits.Grid.maxWidth, hasDoc: true, refMin: refMin.maxWidth, refMax: refMax.maxWidth)
        randomizeDoublePair(min: &min.minHeight, max: &max.minHeight, documented: TerrainFieldDocLimits.Grid.minHeight, hasDoc: true, refMin: refMin.minHeight, refMax: refMax.minHeight)
        randomizeDoublePair(min: &min.maxHeight, max: &max.maxHeight, documented: TerrainFieldDocLimits.Grid.maxHeight, hasDoc: true, refMin: refMin.maxHeight, refMax: refMax.maxHeight)
        randomizeDoublePair(min: &min.minHeightOffset, max: &max.minHeightOffset, documented: TerrainFieldDocLimits.Grid.minHeightOffset, hasDoc: true, refMin: refMin.minHeightOffset, refMax: refMax.minHeightOffset)
        randomizeDoublePair(min: &min.maxHeightOffset, max: &max.maxHeightOffset, documented: TerrainFieldDocLimits.Grid.maxHeightOffset, hasDoc: true, refMin: refMin.maxHeightOffset, refMax: refMax.maxHeightOffset)
        randomizeDoublePair(min: &min.heightOffset, max: &max.heightOffset, documented: TerrainFieldDocLimits.Grid.heightOffset, hasDoc: true, refMin: refMin.heightOffset, refMax: refMax.heightOffset)
        randomizeEnumPair(min: &min.offset.offsetType, max: &max.offset.offsetType, refMin: refMin.offset.offsetType, refMax: refMax.offset.offsetType, hasDoc: false)
        randomizeDoublePair(min: &min.regionRatio, max: &max.regionRatio, documented: TerrainFieldDocLimits.Grid.regionRatio, hasDoc: true, refMin: refMin.regionRatio, refMax: refMax.regionRatio)
        randomizeDoublePair(min: &min.regionScale, max: &max.regionScale, documented: TerrainFieldDocLimits.Grid.regionScale, hasDoc: true, refMin: refMin.regionScale, refMax: refMax.regionScale)
        randomizeUberLayer(min: &min.turbulenceNoiseLayer, max: &max.turbulenceNoiseLayer, refMin: refMin.turbulenceNoiseLayer, refMax: refMax.turbulenceNoiseLayer)
        randomizeDoublePair(min: &min.yaw, max: &max.yaw, documented: TerrainFieldDocLimits.Grid.yaw, hasDoc: true, refMin: refMin.yaw, refMax: refMax.yaw)
        randomizeDoublePair(min: &min.pitch, max: &max.pitch, documented: TerrainFieldDocLimits.Grid.pitch, hasDoc: true, refMin: refMin.pitch, refMax: refMax.pitch)
        randomizeDoublePair(min: &min.roll, max: &max.roll, documented: TerrainFieldDocLimits.Grid.roll, hasDoc: true, refMin: refMin.roll, refMax: refMax.roll)
        randomizeDoublePair(min: &min.varyYaw, max: &max.varyYaw, documented: TerrainFieldDocLimits.Grid.varyYaw, hasDoc: true, refMin: refMin.varyYaw, refMax: refMax.varyYaw)
        randomizeDoublePair(min: &min.varyPitch, max: &max.varyPitch, documented: TerrainFieldDocLimits.Grid.varyPitch, hasDoc: true, refMin: refMin.varyPitch, refMax: refMax.varyPitch)
        randomizeDoublePair(min: &min.varyRoll, max: &max.varyRoll, documented: TerrainFieldDocLimits.Grid.varyRoll, hasDoc: true, refMin: refMin.varyRoll, refMax: refMax.varyRoll)
        randomizeDoublePair(min: &min.smoothRadius, max: &max.smoothRadius, documented: TerrainFieldDocLimits.Grid.smoothRadius, hasDoc: true, refMin: refMin.smoothRadius, refMax: refMax.smoothRadius)
        randomizeIntPair(min: &min.seedOffset, max: &max.seedOffset, range: refMin.seedOffset...refMax.seedOffset, hasDoc: false, refMin: refMin.seedOffset, refMax: refMax.seedOffset)
        randomizeDoublePair(min: &min.randomPrimitive, max: &max.randomPrimitive, documented: TerrainFieldDocLimits.Grid.randomPrimitive, hasDoc: true, refMin: refMin.randomPrimitive, refMax: refMax.randomPrimitive)
        randomizeSuperFormula(min: &min.superFormula1, max: &max.superFormula1, refMin: refMin.superFormula1, refMax: refMax.superFormula1)
        randomizeSuperFormula(min: &min.superFormula2, max: &max.superFormula2, refMin: refMin.superFormula2, refMax: refMax.superFormula2)
        randomizeSuperPrimitive(min: &min.superPrimitive, max: &max.superPrimitive, refMin: refMin.superPrimitive, refMax: refMax.superPrimitive)
        randomizeDoublePair(min: &min.tileBlendMeters, max: &max.tileBlendMeters, documented: TerrainFieldDocLimits.Grid.tileBlendMeters, hasDoc: true, refMin: refMin.tileBlendMeters, refMax: refMax.tileBlendMeters)
    }

    static func randomizeFeature(
        min: inout TkNoiseFeatureData,
        max: inout TkNoiseFeatureData,
        refMin: TkNoiseFeatureData,
        refMax: TkNoiseFeatureData
    ) {
        randomizeBoolPair(min: &min.active, max: &max.active, refMin: refMin.active, refMax: refMax.active, hasDoc: false)
        randomizeIntPair(min: &min.maximumLOD, max: &max.maximumLOD, range: refMin.maximumLOD...refMax.maximumLOD, hasDoc: false, refMin: refMin.maximumLOD, refMax: refMax.maximumLOD)
        randomizeBoolPair(min: &min.subtract, max: &max.subtract, refMin: refMin.subtract, refMax: refMax.subtract, hasDoc: false)
        randomizeBoolPair(min: &min.trench, max: &max.trench, refMin: refMin.trench, refMax: refMax.trench, hasDoc: false)
        randomizeEnumPair(min: &min.voxelType.noiseVoxelType, max: &max.voxelType.noiseVoxelType, refMin: refMin.voxelType.noiseVoxelType, refMax: refMax.voxelType.noiseVoxelType, hasDoc: false)
        randomizeEnumPair(min: &min.featureType, max: &max.featureType, refMin: refMin.featureType, refMax: refMax.featureType, hasDoc: false)
        randomizeDoublePair(min: &min.width, max: &max.width, documented: TerrainFieldDocLimits.Feature.width, hasDoc: true, refMin: refMin.width, refMax: refMax.width)
        randomizeDoublePair(min: &min.height, max: &max.height, documented: TerrainFieldDocLimits.Feature.height, hasDoc: true, refMin: refMin.height, refMax: refMax.height)
        randomizeIntPair(min: &min.octaves, max: &max.octaves, range: refMin.octaves...refMax.octaves, hasDoc: false, refMin: refMin.octaves, refMax: refMax.octaves)
        randomizeDoublePair(min: &min.regionSize, max: &max.regionSize, documented: TerrainFieldDocLimits.Feature.regionSize, hasDoc: true, refMin: refMin.regionSize, refMax: refMax.regionSize)
        randomizeDoublePair(min: &min.ratio, max: &max.ratio, documented: TerrainFieldDocLimits.Feature.ratio, hasDoc: true, refMin: refMin.ratio, refMax: refMax.ratio)
        randomizeDoublePair(min: &min.heightVarianceAmplitude, max: &max.heightVarianceAmplitude, documented: TerrainFieldDocLimits.Feature.heightVarianceAmplitude, hasDoc: true, refMin: refMin.heightVarianceAmplitude, refMax: refMax.heightVarianceAmplitude)
        randomizeDoublePair(min: &min.heightVarianceFrequency, max: &max.heightVarianceFrequency, documented: TerrainFieldDocLimits.Feature.heightVarianceFrequency, hasDoc: true, refMin: refMin.heightVarianceFrequency, refMax: refMax.heightVarianceFrequency)
        randomizeDoublePair(min: &min.heightOffset, max: &max.heightOffset, documented: TerrainFieldDocLimits.Feature.heightOffset, hasDoc: true, refMin: refMin.heightOffset, refMax: refMax.heightOffset)
        randomizeEnumPair(min: &min.offset.offsetType, max: &max.offset.offsetType, refMin: refMin.offset.offsetType, refMax: refMax.offset.offsetType, hasDoc: false)
        randomizeDoublePair(min: &min.smoothRadius, max: &max.smoothRadius, documented: refMin.smoothRadius...refMax.smoothRadius, hasDoc: false, refMin: refMin.smoothRadius, refMax: refMax.smoothRadius)
        randomizeIntPair(min: &min.seedOffset, max: &max.seedOffset, range: refMin.seedOffset...refMax.seedOffset, hasDoc: false, refMin: refMin.seedOffset, refMax: refMax.seedOffset)
        randomizeDoublePair(min: &min.tileBlendMeters, max: &max.tileBlendMeters, documented: TerrainFieldDocLimits.Feature.tileBlendMeters, hasDoc: true, refMin: refMin.tileBlendMeters, refMax: refMax.tileBlendMeters)
    }

    static func randomizeSuperFormula(
        min: inout TkNoiseSuperFormulaData,
        max: inout TkNoiseSuperFormulaData,
        refMin: TkNoiseSuperFormulaData,
        refMax: TkNoiseSuperFormulaData
    ) {
        randomizeDoublePair(min: &min.formM, max: &max.formM, documented: TerrainFieldDocLimits.SuperFormula.formM, hasDoc: true, refMin: refMin.formM, refMax: refMax.formM)
        randomizeDoublePair(min: &min.formN1, max: &max.formN1, documented: TerrainFieldDocLimits.SuperFormula.formN1, hasDoc: true, refMin: refMin.formN1, refMax: refMax.formN1)
        randomizeDoublePair(min: &min.formN2, max: &max.formN2, documented: TerrainFieldDocLimits.SuperFormula.formN2, hasDoc: true, refMin: refMin.formN2, refMax: refMax.formN2)
        randomizeDoublePair(min: &min.formN3, max: &max.formN3, documented: TerrainFieldDocLimits.SuperFormula.formN3, hasDoc: true, refMin: refMin.formN3, refMax: refMax.formN3)
    }

    static func randomizeSuperPrimitive(
        min: inout TkNoiseSuperPrimitiveData,
        max: inout TkNoiseSuperPrimitiveData,
        refMin: TkNoiseSuperPrimitiveData,
        refMax: TkNoiseSuperPrimitiveData
    ) {
        randomizeDoublePair(min: &min.width, max: &max.width, documented: TerrainFieldDocLimits.SuperPrimitive.width, hasDoc: true, refMin: refMin.width, refMax: refMax.width)
        randomizeDoublePair(min: &min.height, max: &max.height, documented: TerrainFieldDocLimits.SuperPrimitive.height, hasDoc: true, refMin: refMin.height, refMax: refMax.height)
        randomizeDoublePair(min: &min.depth, max: &max.depth, documented: TerrainFieldDocLimits.SuperPrimitive.depth, hasDoc: true, refMin: refMin.depth, refMax: refMax.depth)
        randomizeDoublePair(min: &min.thickness, max: &max.thickness, documented: TerrainFieldDocLimits.SuperPrimitive.thickness, hasDoc: true, refMin: refMin.thickness, refMax: refMax.thickness)
        randomizeDoublePair(min: &min.cornerRadiusXY, max: &max.cornerRadiusXY, documented: TerrainFieldDocLimits.SuperPrimitive.cornerRadiusXY, hasDoc: true, refMin: refMin.cornerRadiusXY, refMax: refMax.cornerRadiusXY)
        randomizeDoublePair(min: &min.cornerRadiusZ, max: &max.cornerRadiusZ, documented: TerrainFieldDocLimits.SuperPrimitive.cornerRadiusZ, hasDoc: true, refMin: refMin.cornerRadiusZ, refMax: refMax.cornerRadiusZ)
        randomizeDoublePair(min: &min.bottomRadiusOffset, max: &max.bottomRadiusOffset, documented: TerrainFieldDocLimits.SuperPrimitive.bottomRadiusOffset, hasDoc: true, refMin: refMin.bottomRadiusOffset, refMax: refMax.bottomRadiusOffset)
    }

    // MARK: - Private helpers

    private static func randomizeScalars(
        min: inout TkVoxelGeneratorData,
        max: inout TkVoxelGeneratorData,
        refMin: TkVoxelGeneratorData,
        refMax: TkVoxelGeneratorData
    ) {
        randomizeOptionalSeed(min: &min.baseSeed, max: &max.baseSeed, refMin: refMin.baseSeed, refMax: refMax.baseSeed)
        randomizeDoublePair(min: &min.seaLevel, max: &max.seaLevel, documented: refMin.seaLevel...refMax.seaLevel, hasDoc: false, refMin: refMin.seaLevel, refMax: refMax.seaLevel)
        randomizeDoublePair(min: &min.beachHeight, max: &max.beachHeight, documented: refMin.beachHeight...refMax.beachHeight, hasDoc: false, refMin: refMin.beachHeight, refMax: refMax.beachHeight)
        randomizeDoublePair(min: &min.noSeaBaseLevel, max: &max.noSeaBaseLevel, documented: refMin.noSeaBaseLevel...refMax.noSeaBaseLevel, hasDoc: false, refMin: refMin.noSeaBaseLevel, refMax: refMax.noSeaBaseLevel)
        randomizeEnumPair(min: &min.buildingVoxelType.noiseVoxelType, max: &max.buildingVoxelType.noiseVoxelType, refMin: refMin.buildingVoxelType.noiseVoxelType, refMax: refMax.buildingVoxelType.noiseVoxelType, hasDoc: false)
        randomizeEnumPair(min: &min.resourceVoxelType.noiseVoxelType, max: &max.resourceVoxelType.noiseVoxelType, refMin: refMin.resourceVoxelType.noiseVoxelType, refMax: refMax.resourceVoxelType.noiseVoxelType, hasDoc: false)
        randomizeDoublePair(min: &min.minimumCaveDepth, max: &max.minimumCaveDepth, documented: refMin.minimumCaveDepth...refMax.minimumCaveDepth, hasDoc: false, refMin: refMin.minimumCaveDepth, refMax: refMax.minimumCaveDepth)
        randomizeDoublePair(min: &min.caveRoofSmoothingDist, max: &max.caveRoofSmoothingDist, documented: refMin.caveRoofSmoothingDist...refMax.caveRoofSmoothingDist, hasDoc: false, refMin: refMin.caveRoofSmoothingDist, refMax: refMax.caveRoofSmoothingDist)
        randomizeDoublePair(min: &min.maximumSeaLevelCaveDepth, max: &max.maximumSeaLevelCaveDepth, documented: refMin.maximumSeaLevelCaveDepth...refMax.maximumSeaLevelCaveDepth, hasDoc: false, refMin: refMin.maximumSeaLevelCaveDepth, refMax: refMax.maximumSeaLevelCaveDepth)
        randomizeDoublePair(min: &min.buildingTextureRadius, max: &max.buildingTextureRadius, documented: refMin.buildingTextureRadius...refMax.buildingTextureRadius, hasDoc: false, refMin: refMin.buildingTextureRadius, refMax: refMax.buildingTextureRadius)
        randomizeDoublePair(min: &min.buildingSmoothingRadius, max: &max.buildingSmoothingRadius, documented: refMin.buildingSmoothingRadius...refMax.buildingSmoothingRadius, hasDoc: false, refMin: refMin.buildingSmoothingRadius, refMax: refMax.buildingSmoothingRadius)
        randomizeDoublePair(min: &min.buildingSmoothingHeight, max: &max.buildingSmoothingHeight, documented: refMin.buildingSmoothingHeight...refMax.buildingSmoothingHeight, hasDoc: false, refMin: refMin.buildingSmoothingHeight, refMax: refMax.buildingSmoothingHeight)
        randomizeDoublePair(min: &min.waterFadeInDistance, max: &max.waterFadeInDistance, documented: refMin.waterFadeInDistance...refMax.waterFadeInDistance, hasDoc: false, refMin: refMin.waterFadeInDistance, refMax: refMax.waterFadeInDistance)
    }

    private static func randomizeNoiseLayers(
        min: inout NoiseLayers,
        max: inout NoiseLayers,
        refMin: NoiseLayers,
        refMax: NoiseLayers
    ) {
        randomizeUberLayer(min: &min.base, max: &max.base, refMin: refMin.base, refMax: refMax.base)
        randomizeUberLayer(min: &min.hill, max: &max.hill, refMin: refMin.hill, refMax: refMax.hill)
        randomizeUberLayer(min: &min.mountain, max: &max.mountain, refMin: refMin.mountain, refMax: refMax.mountain)
        randomizeUberLayer(min: &min.rock, max: &max.rock, refMin: refMin.rock, refMax: refMax.rock)
        randomizeUberLayer(min: &min.underWater, max: &max.underWater, refMin: refMin.underWater, refMax: refMax.underWater)
        randomizeUberLayer(min: &min.texture, max: &max.texture, refMin: refMin.texture, refMax: refMax.texture)
        randomizeUberLayer(min: &min.elevation, max: &max.elevation, refMin: refMin.elevation, refMax: refMax.elevation)
        randomizeUberLayer(min: &min.continent, max: &max.continent, refMin: refMin.continent, refMax: refMax.continent)
    }

    private static func randomizeGridLayers(
        min: inout GridLayers,
        max: inout GridLayers,
        refMin: GridLayers,
        refMax: GridLayers
    ) {
        randomizeGrid(min: &min.small, max: &max.small, refMin: refMin.small, refMax: refMax.small)
        randomizeGrid(min: &min.large, max: &max.large, refMin: refMin.large, refMax: refMax.large)
        randomizeGrid(min: &min.resourcesHeridium, max: &max.resourcesHeridium, refMin: refMin.resourcesHeridium, refMax: refMax.resourcesHeridium)
        randomizeGrid(min: &min.resourcesIridium, max: &max.resourcesIridium, refMin: refMin.resourcesIridium, refMax: refMax.resourcesIridium)
        randomizeGrid(min: &min.resourcesCopper, max: &max.resourcesCopper, refMin: refMin.resourcesCopper, refMax: refMax.resourcesCopper)
        randomizeGrid(min: &min.resourcesNickel, max: &max.resourcesNickel, refMin: refMin.resourcesNickel, refMax: refMax.resourcesNickel)
        randomizeGrid(min: &min.resourcesAluminium, max: &max.resourcesAluminium, refMin: refMin.resourcesAluminium, refMax: refMax.resourcesAluminium)
        randomizeGrid(min: &min.resourcesGold, max: &max.resourcesGold, refMin: refMin.resourcesGold, refMax: refMax.resourcesGold)
        randomizeGrid(min: &min.resourcesEmeril, max: &max.resourcesEmeril, refMin: refMin.resourcesEmeril, refMax: refMax.resourcesEmeril)
    }

    private static func randomizeFeatures(
        min: inout Features,
        max: inout Features,
        refMin: Features,
        refMax: Features
    ) {
        randomizeFeature(min: &min.river, max: &max.river, refMin: refMin.river, refMax: refMax.river)
        randomizeFeature(min: &min.crater, max: &max.crater, refMin: refMin.crater, refMax: refMax.crater)
        randomizeFeature(min: &min.arches, max: &max.arches, refMin: refMin.arches, refMax: refMax.arches)
        randomizeFeature(min: &min.archesSmall, max: &max.archesSmall, refMin: refMin.archesSmall, refMax: refMax.archesSmall)
        randomizeFeature(min: &min.blobs, max: &max.blobs, refMin: refMin.blobs, refMax: refMax.blobs)
        randomizeFeature(min: &min.blobsSmall, max: &max.blobsSmall, refMin: refMin.blobsSmall, refMax: refMax.blobsSmall)
        randomizeFeature(min: &min.substance, max: &max.substance, refMin: refMin.substance, refMax: refMax.substance)
    }

    private static func randomizeCaves(
        min: inout Caves,
        max: inout Caves,
        refMin: Caves,
        refMax: Caves
    ) {
        randomizeFeature(min: &min.underground.mouth, max: &max.underground.mouth, refMin: refMin.underground.mouth, refMax: refMax.underground.mouth)
        randomizeFeature(min: &min.underground.tunnel, max: &max.underground.tunnel, refMin: refMin.underground.tunnel, refMax: refMax.underground.tunnel)
    }

    private static func randomizeDoublePair(
        min: inout Double,
        max: inout Double,
        documented: ClosedRange<Double>,
        hasDoc: Bool,
        refMin: Double,
        refMax: Double
    ) {
        let range = TerrainFieldRanges.doubleRange(
            documented: documented,
            aggregatedMin: refMin,
            aggregatedMax: refMax,
            hasDocComment: hasDoc
        )
        let lower = range.lowerBound
        let upper = range.upperBound
        guard lower <= upper else { return }

        let newMin = Double.random(in: lower...upper)
        let newMax = Double.random(in: newMin...upper)
        min = newMin
        max = newMax
    }

    private static func randomizeIntPair(
        min: inout Int,
        max: inout Int,
        range: ClosedRange<Int>,
        hasDoc: Bool,
        refMin: Int,
        refMax: Int
    ) {
        let valid = TerrainFieldRanges.intRange(
            documented: range,
            aggregatedMin: refMin,
            aggregatedMax: refMax,
            hasDocComment: hasDoc
        )
        let lower = valid.lowerBound
        let upper = valid.upperBound
        guard lower <= upper else { return }

        let newMin = Int.random(in: lower...upper)
        let newMax = Int.random(in: newMin...upper)
        min = newMin
        max = newMax
    }

    private static func randomizeBoolPair(
        min: inout Bool,
        max: inout Bool,
        refMin: Bool,
        refMax: Bool,
        hasDoc: Bool
    ) {
        let minBound = hasDoc ? false : (refMin && refMax)
        let maxBound = hasDoc ? true : (refMin || refMax)
        let choices: [Bool] = {
            switch (minBound, maxBound) {
            case (false, false): [false]
            case (true, true): [true]
            case (false, true): [false, true]
            case (true, false): [false, true]
            }
        }()
        min = choices.randomElement() ?? false
        let maxChoices = choices.filter { ($0 ? 1 : 0) >= (min ? 1 : 0) }
        max = maxChoices.randomElement() ?? min
    }

    private static func randomizeEnumPair<T: CaseIterable & Hashable & RawRepresentable>(
        min: inout T,
        max: inout T,
        refMin: T,
        refMax: T,
        hasDoc: Bool
    ) where T.AllCases: RandomAccessCollection, T.RawValue: Comparable {
        let all = Array(T.allCases).sorted { $0.rawValue < $1.rawValue }
        let lowerIndex: Int
        let upperIndex: Int
        if hasDoc {
            lowerIndex = 0
            upperIndex = all.count - 1
        } else {
            let loValue = Swift.min(refMin.rawValue, refMax.rawValue)
            let hiValue = Swift.max(refMin.rawValue, refMax.rawValue)
            lowerIndex = all.firstIndex { $0.rawValue == loValue } ?? 0
            upperIndex = all.firstIndex { $0.rawValue == hiValue } ?? all.count - 1
        }
        let lo = Swift.min(lowerIndex, upperIndex)
        let hi = Swift.max(lowerIndex, upperIndex)
        let minIdx: Int
        let maxIdx: Int
        if lo == hi, all.count > 1 {
            minIdx = Int.random(in: 0...all.count - 1)
            maxIdx = Int.random(in: minIdx...all.count - 1)
        } else {
            minIdx = Int.random(in: lo...hi)
            maxIdx = Int.random(in: minIdx...hi)
        }
        min = all[minIdx]
        max = all[maxIdx]
    }

    private static func randomizeOptionalSeed(
        min: inout BaseSeed,
        max: inout BaseSeed,
        refMin: BaseSeed,
        refMax: BaseSeed
    ) {
        let refMinValue = refMin.seed
        let refMaxValue = refMax.seed
        let lower = Swift.min(refMinValue ?? 0, refMaxValue ?? 0)
        let upper = Swift.max(refMinValue ?? 0, refMaxValue ?? 0)
        if refMinValue == nil, refMaxValue == nil {
            min = BaseSeed(seed: nil)
            max = BaseSeed(seed: nil)
        } else if refMinValue == nil {
            let value = Int.random(in: (refMaxValue ?? upper)...upper)
            min = BaseSeed(seed: value)
            max = BaseSeed(seed: value)
        } else {
            let newMin = Int.random(in: lower...upper)
            let newMax = Int.random(in: newMin...upper)
            min = BaseSeed(seed: newMin)
            max = BaseSeed(seed: newMax)
        }
    }
}