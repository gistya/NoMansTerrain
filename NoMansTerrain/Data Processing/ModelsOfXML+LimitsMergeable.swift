
extension BaseSeed: LimitsMergeable {
    func merged(with other: BaseSeed, direction: MergeDirection) -> BaseSeed {
        BaseSeed(seed: mergeOptionalInt(seed, other.seed, direction: direction))
    }
}


extension TkNoiseVoxelTypeEnum: LimitsMergeable {
    func merged(with other: TkNoiseVoxelTypeEnum, direction: MergeDirection) -> TkNoiseVoxelTypeEnum {
        TkNoiseVoxelTypeEnum(noiseVoxelType: mergeEnum(noiseVoxelType, other.noiseVoxelType, direction: direction))
    }
}

extension TkNoiseOffsetEnum: LimitsMergeable {
    func merged(with other: TkNoiseOffsetEnum, direction: MergeDirection) -> TkNoiseOffsetEnum {
        TkNoiseOffsetEnum(offsetType: mergeEnum(offsetType, other.offsetType, direction: direction))
    }
}

extension TkNoiseSuperFormulaData: LimitsMergeable {
    func merged(with other: TkNoiseSuperFormulaData, direction: MergeDirection) -> TkNoiseSuperFormulaData {
        TkNoiseSuperFormulaData(
            formM: merge(formM, other.formM, direction: direction),
            formN1: merge(formN1, other.formN1, direction: direction),
            formN2: merge(formN2, other.formN2, direction: direction),
            formN3: merge(formN3, other.formN3, direction: direction)
        )
    }
}

extension TkNoiseSuperPrimitiveData: LimitsMergeable {
    func merged(with other: TkNoiseSuperPrimitiveData, direction: MergeDirection) -> TkNoiseSuperPrimitiveData {
        TkNoiseSuperPrimitiveData(
            width: merge(width, other.width, direction: direction),
            height: merge(height, other.height, direction: direction),
            depth: merge(depth, other.depth, direction: direction),
            thickness: merge(thickness, other.thickness, direction: direction),
            cornerRadiusXY: merge(cornerRadiusXY, other.cornerRadiusXY, direction: direction),
            cornerRadiusZ: merge(cornerRadiusZ, other.cornerRadiusZ, direction: direction),
            bottomRadiusOffset: merge(bottomRadiusOffset, other.bottomRadiusOffset, direction: direction)
        )
    }
}

extension TkNoiseUberData: LimitsMergeable {
    func merged(with other: TkNoiseUberData, direction: MergeDirection) -> TkNoiseUberData {
        TkNoiseUberData(
            octaves: merge(octaves, other.octaves, direction: direction),
            slopeGain: merge(slopeGain, other.slopeGain, direction: direction),
            slopeBias: merge(slopeBias, other.slopeBias, direction: direction),
            sharpToRoundFeatures: merge(sharpToRoundFeatures, other.sharpToRoundFeatures, direction: direction),
            amplifyFeatures: merge(amplifyFeatures, other.amplifyFeatures, direction: direction),
            perturbFeatures: merge(perturbFeatures, other.perturbFeatures, direction: direction),
            altitudeErosion: merge(altitudeErosion, other.altitudeErosion, direction: direction),
            ridgeErosion: merge(ridgeErosion, other.ridgeErosion, direction: direction),
            slopeErosion: merge(slopeErosion, other.slopeErosion, direction: direction),
            lacunarity: merge(lacunarity, other.lacunarity, direction: direction),
            gain: merge(gain, other.gain, direction: direction),
            remapFromMin: merge(remapFromMin, other.remapFromMin, direction: direction),
            remapFromMax: merge(remapFromMax, other.remapFromMax, direction: direction),
            remapToMin: merge(remapToMin, other.remapToMin, direction: direction),
            remapToMax: merge(remapToMax, other.remapToMax, direction: direction),
            debugNoiseType: mergeEnum(debugNoiseType, other.debugNoiseType, direction: direction)
        )
    }
}

extension TkNoiseUberLayerData: LimitsMergeable {
    func merged(with other: TkNoiseUberLayerData, direction: MergeDirection) -> TkNoiseUberLayerData {
        TkNoiseUberLayerData(
            noiseData: noiseData.merged(with: other.noiseData, direction: direction),
            active: mergeBool(active, other.active, direction: direction),
            maximumLOD: merge(maximumLOD, other.maximumLOD, direction: direction),
            subtract: mergeBool(subtract, other.subtract, direction: direction),
            voxelType: voxelType.merged(with: other.voxelType, direction: direction),
            height: merge(height, other.height, direction: direction),
            width: merge(width, other.width, direction: direction),
            regionRatio: merge(regionRatio, other.regionRatio, direction: direction),
            regionScale: merge(regionScale, other.regionScale, direction: direction),
            regionGain: merge(regionGain, other.regionGain, direction: direction),
            smoothRadius: merge(smoothRadius, other.smoothRadius, direction: direction),
            heightOffset: merge(heightOffset, other.heightOffset, direction: direction),
            offset: offset.merged(with: other.offset, direction: direction),
            waterFade: mergeEnum(waterFade, other.waterFade, direction: direction),
            plateauStratas: merge(plateauStratas, other.plateauStratas, direction: direction),
            plateauSharpness: merge(plateauSharpness, other.plateauSharpness, direction: direction),
            plateauRegionSize: merge(plateauRegionSize, other.plateauRegionSize, direction: direction),
            seedOffset: merge(seedOffset, other.seedOffset, direction: direction),
            tileBlendMeters: merge(tileBlendMeters, other.tileBlendMeters, direction: direction)
        )
    }
}

extension TkNoiseGridData: LimitsMergeable {
    func merged(with other: TkNoiseGridData, direction: MergeDirection) -> TkNoiseGridData {
        TkNoiseGridData(
            active: mergeBool(active, other.active, direction: direction),
            maximumLOD: merge(maximumLOD, other.maximumLOD, direction: direction),
            subtract: mergeBool(subtract, other.subtract, direction: direction),
            swapZY: mergeBool(swapZY, other.swapZY, direction: direction),
            hemisphere: mergeBool(hemisphere, other.hemisphere, direction: direction),
            voxelType: voxelType.merged(with: other.voxelType, direction: direction),
            noiseGridType: mergeEnum(noiseGridType, other.noiseGridType, direction: direction),
            filename: mergeString(filename, other.filename, direction: direction),
            minWidth: merge(minWidth, other.minWidth, direction: direction),
            maxWidth: merge(maxWidth, other.maxWidth, direction: direction),
            minHeight: merge(minHeight, other.minHeight, direction: direction),
            maxHeight: merge(maxHeight, other.maxHeight, direction: direction),
            minHeightOffset: merge(minHeightOffset, other.minHeightOffset, direction: direction),
            maxHeightOffset: merge(maxHeightOffset, other.maxHeightOffset, direction: direction),
            heightOffset: merge(heightOffset, other.heightOffset, direction: direction),
            offset: offset.merged(with: other.offset, direction: direction),
            regionRatio: merge(regionRatio, other.regionRatio, direction: direction),
            regionScale: merge(regionScale, other.regionScale, direction: direction),
            turbulenceNoiseLayer: turbulenceNoiseLayer.merged(with: other.turbulenceNoiseLayer, direction: direction),
            yaw: merge(yaw, other.yaw, direction: direction),
            pitch: merge(pitch, other.pitch, direction: direction),
            roll: merge(roll, other.roll, direction: direction),
            varyYaw: merge(varyYaw, other.varyYaw, direction: direction),
            varyPitch: merge(varyPitch, other.varyPitch, direction: direction),
            varyRoll: merge(varyRoll, other.varyRoll, direction: direction),
            smoothRadius: merge(smoothRadius, other.smoothRadius, direction: direction),
            seedOffset: merge(seedOffset, other.seedOffset, direction: direction),
            randomPrimitive: merge(randomPrimitive, other.randomPrimitive, direction: direction),
            superFormula1: superFormula1.merged(with: other.superFormula1, direction: direction),
            superFormula2: superFormula2.merged(with: other.superFormula2, direction: direction),
            superPrimitive: superPrimitive.merged(with: other.superPrimitive, direction: direction),
            tileBlendMeters: merge(tileBlendMeters, other.tileBlendMeters, direction: direction)
        )
    }
}

extension TkNoiseFeatureData: LimitsMergeable {
    func merged(with other: TkNoiseFeatureData, direction: MergeDirection) -> TkNoiseFeatureData {
        TkNoiseFeatureData(
            active: mergeBool(active, other.active, direction: direction),
            maximumLOD: merge(maximumLOD, other.maximumLOD, direction: direction),
            subtract: mergeBool(subtract, other.subtract, direction: direction),
            trench: mergeBool(trench, other.trench, direction: direction),
            voxelType: voxelType.merged(with: other.voxelType, direction: direction),
            featureType: mergeEnum(featureType, other.featureType, direction: direction),
            width: merge(width, other.width, direction: direction),
            height: merge(height, other.height, direction: direction),
            octaves: merge(octaves, other.octaves, direction: direction),
            regionSize: merge(regionSize, other.regionSize, direction: direction),
            ratio: merge(ratio, other.ratio, direction: direction),
            heightVarianceAmplitude: merge(heightVarianceAmplitude, other.heightVarianceAmplitude, direction: direction),
            heightVarianceFrequency: merge(heightVarianceFrequency, other.heightVarianceFrequency, direction: direction),
            heightOffset: merge(heightOffset, other.heightOffset, direction: direction),
            offset: offset.merged(with: other.offset, direction: direction),
            smoothRadius: merge(smoothRadius, other.smoothRadius, direction: direction),
            seedOffset: merge(seedOffset, other.seedOffset, direction: direction),
            tileBlendMeters: merge(tileBlendMeters, other.tileBlendMeters, direction: direction)
        )
    }
}

extension TkNoiseCaveData: LimitsMergeable {
    func merged(with other: TkNoiseCaveData, direction: MergeDirection) -> TkNoiseCaveData {
        TkNoiseCaveData(
            mouth: mouth.merged(with: other.mouth, direction: direction),
            tunnel: tunnel.merged(with: other.tunnel, direction: direction)
        )
    }
}

extension NoiseLayers: LimitsMergeable {
    func merged(with other: NoiseLayers, direction: MergeDirection) -> NoiseLayers {
        NoiseLayers(
            base: base.merged(with: other.base, direction: direction),
            hill: hill.merged(with: other.hill, direction: direction),
            mountain: mountain.merged(with: other.mountain, direction: direction),
            rock: rock.merged(with: other.rock, direction: direction),
            underWater: underWater.merged(with: other.underWater, direction: direction),
            texture: texture.merged(with: other.texture, direction: direction),
            elevation: elevation.merged(with: other.elevation, direction: direction),
            continent: continent.merged(with: other.continent, direction: direction)
        )
    }
}

extension GridLayers: LimitsMergeable {
    func merged(with other: GridLayers, direction: MergeDirection) -> GridLayers {
        GridLayers(
            small: small.merged(with: other.small, direction: direction),
            large: large.merged(with: other.large, direction: direction),
            resourcesHeridium: resourcesHeridium.merged(with: other.resourcesHeridium, direction: direction),
            resourcesIridium: resourcesIridium.merged(with: other.resourcesIridium, direction: direction),
            resourcesCopper: resourcesCopper.merged(with: other.resourcesCopper, direction: direction),
            resourcesNickel: resourcesNickel.merged(with: other.resourcesNickel, direction: direction),
            resourcesAluminium: resourcesAluminium.merged(with: other.resourcesAluminium, direction: direction),
            resourcesGold: resourcesGold.merged(with: other.resourcesGold, direction: direction),
            resourcesEmeril: resourcesEmeril.merged(with: other.resourcesEmeril, direction: direction)
        )
    }
}

extension Features: LimitsMergeable {
    func merged(with other: Features, direction: MergeDirection) -> Features {
        Features(
            river: river.merged(with: other.river, direction: direction),
            crater: crater.merged(with: other.crater, direction: direction),
            arches: arches.merged(with: other.arches, direction: direction),
            archesSmall: archesSmall.merged(with: other.archesSmall, direction: direction),
            blobs: blobs.merged(with: other.blobs, direction: direction),
            blobsSmall: blobsSmall.merged(with: other.blobsSmall, direction: direction),
            substance: substance.merged(with: other.substance, direction: direction)
        )
    }
}

extension Caves: LimitsMergeable {
    func merged(with other: Caves, direction: MergeDirection) -> Caves {
        Caves(underground: underground.merged(with: other.underground, direction: direction))
    }
}

extension TkVoxelGeneratorData: LimitsMergeable {
    func merged(with other: TkVoxelGeneratorData, direction: MergeDirection) -> TkVoxelGeneratorData {
        TkVoxelGeneratorData(
            baseSeed: baseSeed.merged(with: other.baseSeed, direction: direction),
            seaLevel: merge(seaLevel, other.seaLevel, direction: direction),
            beachHeight: merge(beachHeight, other.beachHeight, direction: direction),
            noSeaBaseLevel: merge(noSeaBaseLevel, other.noSeaBaseLevel, direction: direction),
            buildingVoxelType: buildingVoxelType.merged(with: other.buildingVoxelType, direction: direction),
            resourceVoxelType: resourceVoxelType.merged(with: other.resourceVoxelType, direction: direction),
            noiseLayers: noiseLayers.merged(with: other.noiseLayers, direction: direction),
            gridLayers: gridLayers.merged(with: other.gridLayers, direction: direction),
            features: features.merged(with: other.features, direction: direction),
            caves: caves.merged(with: other.caves, direction: direction),
            minimumCaveDepth: merge(minimumCaveDepth, other.minimumCaveDepth, direction: direction),
            caveRoofSmoothingDist: merge(caveRoofSmoothingDist, other.caveRoofSmoothingDist, direction: direction),
            maximumSeaLevelCaveDepth: merge(maximumSeaLevelCaveDepth, other.maximumSeaLevelCaveDepth, direction: direction),
            buildingTextureRadius: merge(buildingTextureRadius, other.buildingTextureRadius, direction: direction),
            buildingSmoothingRadius: merge(buildingSmoothingRadius, other.buildingSmoothingRadius, direction: direction),
            buildingSmoothingHeight: merge(buildingSmoothingHeight, other.buildingSmoothingHeight, direction: direction),
            waterFadeInDistance: merge(waterFadeInDistance, other.waterFadeInDistance, direction: direction)
        )
    }
}
