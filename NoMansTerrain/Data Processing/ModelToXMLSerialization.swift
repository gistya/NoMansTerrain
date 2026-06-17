import Hastings
import Foundation

enum NMSPropertySerializer {
    static func write(limit: Terrain.Limit, _ data: TkVoxelGeneratorData, to url: URL) throws {
        try write(rootName: limit.rawValue, data: data, to: url)
    }

    private static func write(rootName: String, data: TkVoxelGeneratorData, to url: URL) throws {
        let doc = XDM.document {
            element("Property", attributes: [attr("name", rootName), attr("value", "TkVoxelGeneratorData")]) {
                voxelGeneratorProperties(data)
            }
        }

        guard let root = doc.documentElement else {
            throw TerrainLimitsMergerError.writeFailed(url, NSError(domain: "NMSPropertySerializer", code: 1))
        }

        let body = XMLSerializer.serialize(
            root,
            options: .init(indent: true, indentUnit: "\t", omitXMLDeclaration: true)
        )
        let xml = "\n" + body + "\n"
        try xml.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - Combined settings file

    /// One terrain in the combined `cTkVoxelGeneratorSettingsArray` document.
    struct CombinedEntry {
        let name: String
        let min: TkVoxelGeneratorData
        let max: TkVoxelGeneratorData
    }

    /// Builds the single "big daddy" file that the game ships — every terrain's
    /// Min/Max pair under one `cTkVoxelGeneratorSettingsArray` root — and writes it.
    static func writeCombined(_ entries: [CombinedEntry], to url: URL) throws {
        let doc = XDM.document {
            element("Data", attributes: [attr("template", "cTkVoxelGeneratorSettingsArray")]) {
                element("Property", attributes: [attr("name", "TerrainSettings")]) {
                    for entry in entries {
                        settingsElement(entry)
                    }
                }
            }
        }

        guard let root = doc.documentElement else {
            throw TerrainLimitsMergerError.writeFailed(url, NSError(domain: "NMSPropertySerializer", code: 2))
        }

        let body = XMLSerializer.serialize(
            root,
            options: .init(indent: true, indentUnit: "\t", omitXMLDeclaration: true)
        )
        let xml = "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n" + body + "\n"
        try xml.write(to: url, atomically: true, encoding: .utf8)
    }

    @DocumentBuilder
    private static func settingsElement(_ entry: CombinedEntry) -> [NodeSpec] {
        element("Property", attributes: [attr("name", entry.name), attr("value", "TkVoxelGeneratorSettingsElement")]) {
            element("Property", attributes: [attr("name", "Min"), attr("value", "TkVoxelGeneratorData")]) {
                voxelGeneratorProperties(entry.min)
            }
            element("Property", attributes: [attr("name", "Max"), attr("value", "TkVoxelGeneratorData")]) {
                voxelGeneratorProperties(entry.max)
            }
        }
    }

    @DocumentBuilder
    private static func voxelGeneratorProperties(_ data: TkVoxelGeneratorData) -> [NodeSpec] {
        baseSeedProperty(data.baseSeed)
        scalarProperty("SeaLevel", value: formatDouble(data.seaLevel))
        scalarProperty("BeachHeight", value: formatDouble(data.beachHeight))
        scalarProperty("NoSeaBaseLevel", value: formatDouble(data.noSeaBaseLevel))
        typedProperty("BuildingVoxelType", type: "TkNoiseVoxelTypeEnum") { voxelTypeProperties(data.buildingVoxelType) }
        typedProperty("ResourceVoxelType", type: "TkNoiseVoxelTypeEnum") { voxelTypeProperties(data.resourceVoxelType) }
        containerProperty("NoiseLayers") { noiseLayerProperties(data.noiseLayers) }
        containerProperty("GridLayers") { gridLayerProperties(data.gridLayers) }
        containerProperty("Features") { featureGroupProperties(data.features) }
        containerProperty("Caves") { caveProperties(data.caves) }
        scalarProperty("MinimumCaveDepth", value: formatDouble(data.minimumCaveDepth))
        scalarProperty("CaveRoofSmoothingDist", value: formatDouble(data.caveRoofSmoothingDist))
        scalarProperty("MaximumSeaLevelCaveDepth", value: formatDouble(data.maximumSeaLevelCaveDepth))
        scalarProperty("BuildingTextureRadius", value: formatDouble(data.buildingTextureRadius))
        scalarProperty("BuildingSmoothingRadius", value: formatDouble(data.buildingSmoothingRadius))
        scalarProperty("BuildingSmoothingHeight", value: formatDouble(data.buildingSmoothingHeight))
        scalarProperty("WaterFadeInDistance", value: formatDouble(data.waterFadeInDistance))
    }

    @DocumentBuilder
    private static func noiseLayerProperties(_ layers: NoiseLayers) -> [NodeSpec] {
        uberLayerProperty("Base", layers.base)
        uberLayerProperty("Hill", layers.hill)
        uberLayerProperty("Mountain", layers.mountain)
        uberLayerProperty("Rock", layers.rock)
        uberLayerProperty("UnderWater", layers.underWater)
        uberLayerProperty("Texture", layers.texture)
        uberLayerProperty("Elevation", layers.elevation)
        uberLayerProperty("Continent", layers.continent)
    }

    @DocumentBuilder
    private static func gridLayerProperties(_ layers: GridLayers) -> [NodeSpec] {
        gridLayerProperty("Small", layers.small)
        gridLayerProperty("Large", layers.large)
        gridLayerProperty("Resources_Heridium", layers.resourcesHeridium)
        gridLayerProperty("Resources_Iridium", layers.resourcesIridium)
        gridLayerProperty("Resources_Copper", layers.resourcesCopper)
        gridLayerProperty("Resources_Nickel", layers.resourcesNickel)
        gridLayerProperty("Resources_Aluminium", layers.resourcesAluminium)
        gridLayerProperty("Resources_Gold", layers.resourcesGold)
        gridLayerProperty("Resources_Emeril", layers.resourcesEmeril)
    }

    @DocumentBuilder
    private static func featureGroupProperties(_ features: Features) -> [NodeSpec] {
        featureProperty("River", features.river)
        featureProperty("Crater", features.crater)
        featureProperty("Arches", features.arches)
        featureProperty("ArchesSmall", features.archesSmall)
        featureProperty("Blobs", features.blobs)
        featureProperty("BlobsSmall", features.blobsSmall)
        featureProperty("Substance", features.substance)
    }

    @DocumentBuilder
    private static func caveProperties(_ caves: Caves) -> [NodeSpec] {
        typedProperty("Underground", type: "TkNoiseCaveData") {
            featureProperty("Mouth", caves.underground.mouth)
            featureProperty("Tunnel", caves.underground.tunnel)
        }
    }

    @DocumentBuilder
    private static func uberLayerProperty(_ name: String, _ layer: TkNoiseUberLayerData) -> [NodeSpec] {
        typedProperty(name, type: "TkNoiseUberLayerData") {
            uberLayerContents(layer)
        }
    }

    @DocumentBuilder
    private static func uberLayerContents(_ layer: TkNoiseUberLayerData) -> [NodeSpec] {
        typedProperty("NoiseData", type: "TkNoiseUberData") { uberDataProperties(layer.noiseData) }
        scalarProperty("Active", value: formatBool(layer.active))
        scalarProperty("MaximumLOD", value: String(layer.maximumLOD))
        scalarProperty("Subtract", value: formatBool(layer.subtract))
        typedProperty("VoxelType", type: "TkNoiseVoxelTypeEnum") { voxelTypeProperties(layer.voxelType) }
        scalarProperty("Height", value: formatDouble(layer.height))
        scalarProperty("Width", value: formatDouble(layer.width))
        scalarProperty("RegionRatio", value: formatDouble(layer.regionRatio))
        scalarProperty("RegionScale", value: formatDouble(layer.regionScale))
        scalarProperty("RegionGain", value: formatDouble(layer.regionGain))
        scalarProperty("SmoothRadius", value: formatDouble(layer.smoothRadius))
        scalarProperty("HeightOffset", value: formatDouble(layer.heightOffset))
        typedProperty("Offset", type: "TkNoiseOffsetEnum") { offsetProperties(layer.offset) }
        scalarProperty("WaterFade", value: layer.waterFade.rawValue)
        scalarProperty("PlateauStratas", value: formatDouble(layer.plateauStratas))
        scalarProperty("PlateauSharpness", value: String(layer.plateauSharpness))
        scalarProperty("PlateauRegionSize", value: formatDouble(layer.plateauRegionSize))
        scalarProperty("SeedOffset", value: String(layer.seedOffset))
        scalarProperty("TileBlendMeters", value: formatDouble(layer.tileBlendMeters))
    }

    @DocumentBuilder
    private static func gridLayerProperty(_ name: String, _ layer: TkNoiseGridData) -> [NodeSpec] {
        typedProperty(name, type: "TkNoiseGridData") {
            scalarProperty("Active", value: formatBool(layer.active))
            scalarProperty("MaximumLOD", value: String(layer.maximumLOD))
            scalarProperty("Subtract", value: formatBool(layer.subtract))
            scalarProperty("SwapZY", value: formatBool(layer.swapZY))
            scalarProperty("Hemisphere", value: formatBool(layer.hemisphere))
            typedProperty("VoxelType", type: "TkNoiseVoxelTypeEnum") { voxelTypeProperties(layer.voxelType) }
            scalarProperty("NoiseGridType", value: layer.noiseGridType.rawValue)
            scalarProperty("Filename", value: layer.filename)
            scalarProperty("MinWidth", value: formatDouble(layer.minWidth))
            scalarProperty("MaxWidth", value: formatDouble(layer.maxWidth))
            scalarProperty("MinHeight", value: formatDouble(layer.minHeight))
            scalarProperty("MaxHeight", value: formatDouble(layer.maxHeight))
            scalarProperty("MinHeightOffset", value: formatDouble(layer.minHeightOffset))
            scalarProperty("MaxHeightOffset", value: formatDouble(layer.maxHeightOffset))
            scalarProperty("HeightOffset", value: formatDouble(layer.heightOffset))
            typedProperty("Offset", type: "TkNoiseOffsetEnum") { offsetProperties(layer.offset) }
            scalarProperty("RegionRatio", value: formatDouble(layer.regionRatio))
            scalarProperty("RegionScale", value: formatDouble(layer.regionScale))
            typedProperty("TurbulenceNoiseLayer", type: "TkNoiseUberLayerData") {
                uberLayerContents(layer.turbulenceNoiseLayer)
            }
            scalarProperty("Yaw", value: formatDouble(layer.yaw))
            scalarProperty("Pitch", value: formatDouble(layer.pitch))
            scalarProperty("Roll", value: formatDouble(layer.roll))
            scalarProperty("VaryYaw", value: formatDouble(layer.varyYaw))
            scalarProperty("VaryPitch", value: formatDouble(layer.varyPitch))
            scalarProperty("VaryRoll", value: formatDouble(layer.varyRoll))
            scalarProperty("SmoothRadius", value: formatDouble(layer.smoothRadius))
            scalarProperty("SeedOffset", value: String(layer.seedOffset))
            scalarProperty("RandomPrimitive", value: formatDouble(layer.randomPrimitive))
            typedProperty("SuperFormula1", type: "TkNoiseSuperFormulaData") { superFormulaProperties(layer.superFormula1) }
            typedProperty("SuperFormula2", type: "TkNoiseSuperFormulaData") { superFormulaProperties(layer.superFormula2) }
            typedProperty("SuperPrimitive", type: "TkNoiseSuperPrimitiveData") { superPrimitiveProperties(layer.superPrimitive) }
            scalarProperty("TileBlendMeters", value: formatDouble(layer.tileBlendMeters))
        }
    }

    @DocumentBuilder
    private static func featureProperty(_ name: String, _ feature: TkNoiseFeatureData) -> [NodeSpec] {
        typedProperty(name, type: "TkNoiseFeatureData") {
            scalarProperty("Active", value: formatBool(feature.active))
            scalarProperty("MaximumLOD", value: String(feature.maximumLOD))
            scalarProperty("Subtract", value: formatBool(feature.subtract))
            scalarProperty("Trench", value: formatBool(feature.trench))
            typedProperty("VoxelType", type: "TkNoiseVoxelTypeEnum") { voxelTypeProperties(feature.voxelType) }
            scalarProperty("FeatureType", value: feature.featureType.rawValue)
            scalarProperty("Width", value: formatDouble(feature.width))
            scalarProperty("Height", value: formatDouble(feature.height))
            scalarProperty("Octaves", value: String(feature.octaves))
            scalarProperty("RegionSize", value: formatDouble(feature.regionSize))
            scalarProperty("Ratio", value: formatDouble(feature.ratio))
            scalarProperty("HeightVarianceAmplitude", value: formatDouble(feature.heightVarianceAmplitude))
            scalarProperty("HeightVarianceFrequency", value: formatDouble(feature.heightVarianceFrequency))
            scalarProperty("HeightOffset", value: formatDouble(feature.heightOffset))
            typedProperty("Offset", type: "TkNoiseOffsetEnum") { offsetProperties(feature.offset) }
            scalarProperty("SmoothRadius", value: formatDouble(feature.smoothRadius))
            scalarProperty("SeedOffset", value: String(feature.seedOffset))
            scalarProperty("TileBlendMeters", value: formatDouble(feature.tileBlendMeters))
        }
    }

    @DocumentBuilder
    private static func uberDataProperties(_ data: TkNoiseUberData) -> [NodeSpec] {
        scalarProperty("Octaves", value: String(data.octaves))
        scalarProperty("SlopeGain", value: formatDouble(data.slopeGain))
        scalarProperty("SlopeBias", value: formatDouble(data.slopeBias))
        scalarProperty("SharpToRoundFeatures", value: formatDouble(data.sharpToRoundFeatures))
        scalarProperty("AmplifyFeatures", value: formatDouble(data.amplifyFeatures))
        scalarProperty("PerturbFeatures", value: formatDouble(data.perturbFeatures))
        scalarProperty("AltitudeErosion", value: formatDouble(data.altitudeErosion))
        scalarProperty("RidgeErosion", value: formatDouble(data.ridgeErosion))
        scalarProperty("SlopeErosion", value: formatDouble(data.slopeErosion))
        scalarProperty("Lacunarity", value: formatDouble(data.lacunarity))
        scalarProperty("Gain", value: formatDouble(data.gain))
        scalarProperty("Remap From Min", value: formatDouble(data.remapFromMin))
        scalarProperty("Remap From Max", value: formatDouble(data.remapFromMax))
        scalarProperty("Remap To Min", value: formatDouble(data.remapToMin))
        scalarProperty("Remap To Max", value: formatDouble(data.remapToMax))
        scalarProperty("DebugNoiseType", value: data.debugNoiseType.rawValue)
    }

    @DocumentBuilder
    private static func superFormulaProperties(_ data: TkNoiseSuperFormulaData) -> [NodeSpec] {
        scalarProperty("Form_m", value: formatDouble(data.formM))
        scalarProperty("Form_n1", value: formatDouble(data.formN1))
        scalarProperty("Form_n2", value: formatDouble(data.formN2))
        scalarProperty("Form_n3", value: formatDouble(data.formN3))
    }

    @DocumentBuilder
    private static func superPrimitiveProperties(_ data: TkNoiseSuperPrimitiveData) -> [NodeSpec] {
        scalarProperty("Width", value: formatDouble(data.width))
        scalarProperty("Height", value: formatDouble(data.height))
        scalarProperty("Depth", value: formatDouble(data.depth))
        scalarProperty("Thickness", value: formatDouble(data.thickness))
        scalarProperty("CornerRadiusXY", value: formatDouble(data.cornerRadiusXY))
        scalarProperty("CornerRadiusZ", value: formatDouble(data.cornerRadiusZ))
        scalarProperty("BottomRadiusOffset", value: formatDouble(data.bottomRadiusOffset))
    }

    @DocumentBuilder
    private static func voxelTypeProperties(_ voxelType: TkNoiseVoxelTypeEnum) -> [NodeSpec] {
        scalarProperty("NoiseVoxelType", value: voxelType.noiseVoxelType.rawValue)
    }

    @DocumentBuilder
    private static func offsetProperties(_ offset: TkNoiseOffsetEnum) -> [NodeSpec] {
        scalarProperty("OffsetType", value: offset.offsetType.rawValue)
    }

    @DocumentBuilder
    private static func baseSeedProperty(_ seed: BaseSeed) -> [NodeSpec] {
        if let value = seed.seed {
            scalarProperty("BaseSeed", value: String(value))
        } else {
            scalarProperty("BaseSeed", value: "NONE")
        }
    }

    @DocumentBuilder
    private static func scalarProperty(_ name: String, value: String) -> [NodeSpec] {
        element("Property", attributes: [attr("name", name), attr("value", value)])
    }

    @DocumentBuilder
    private static func typedProperty(_ name: String, type: String, @DocumentBuilder content: () -> [NodeSpec]) -> [NodeSpec] {
        element("Property", attributes: [attr("name", name), attr("value", type)]) {
            content()
        }
    }

    @DocumentBuilder
    private static func containerProperty(_ name: String, @DocumentBuilder content: () -> [NodeSpec]) -> [NodeSpec] {
        element("Property", attributes: [attr("name", name)]) {
            content()
        }
    }

    private static func formatDouble(_ value: Double) -> String {
        String(format: "%.6f", value)
    }

    private static func formatBool(_ value: Bool) -> String {
        value ? "true" : "false"
    }
}
