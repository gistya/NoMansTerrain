import Foundation
import Hastings

typealias XMLParser = HastingsXML.XMLParser
typealias XMLSerializer = HastingsXML.XMLSerializer

enum MergeDirection {
    case minimum
    case maximum
}

enum TerrainLimitsMergerError: Error, CustomStringConvertible {
    case noFilesLoaded(kind: String)
    case writeFailed(URL, Error)

    var description: String {
        switch self {
        case .noFilesLoaded(let kind):
            return "No \(kind) terrain limit files could be loaded."
        case .writeFailed(let url, let error):
            return "Failed to write \(url.lastPathComponent): \(error)"
        }
    }
}

struct TerrainLimitsMerger {
    private static let decoder = XMLDecoder(keyStrategy: .attribute(name: "name", value: "value"))

    let mins: [TkVoxelGeneratorData]
    let maxs: [TkVoxelGeneratorData]
    let skippedFiles: [String]

    var aggregatedMin: TkVoxelGeneratorData? {
        aggregate(mins, direction: .minimum)
    }

    var aggregatedMax: TkVoxelGeneratorData? {
        aggregate(maxs, direction: .maximum)
    }

    init(terrainDirectory: URL) throws {
        let fileManager = FileManager.default
        let minURLs = try fileManager.contentsOfDirectory(
            at: terrainDirectory.appendingPathComponent("Min", isDirectory: true),
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "xml" }

        let maxURLs = try fileManager.contentsOfDirectory(
            at: terrainDirectory.appendingPathComponent("Max", isDirectory: true),
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "xml" }

        self.init(minURLs: minURLs, maxURLs: maxURLs)
    }

    init(minURLs: [URL], maxURLs: [URL]) {
        var loadedMins: [TkVoxelGeneratorData] = []
        var loadedMaxs: [TkVoxelGeneratorData] = []
        var skipped: [String] = []

        for url in minURLs {
            switch Self.loadTerrainMin(from: url) {
            case .success(let data):
                loadedMins.append(data)
            case .failure:
                skipped.append(url.lastPathComponent)
            }
        }

        for url in maxURLs {
            switch Self.loadTerrainMax(from: url) {
            case .success(let data):
                loadedMaxs.append(data)
            case .failure:
                skipped.append(url.lastPathComponent)
            }
        }

        mins = loadedMins
        maxs = loadedMaxs
        skippedFiles = skipped
    }

    init(bundle: Bundle = .main) {
        let minURLs = (bundle.urls(forResourcesWithExtension: "xml", subdirectory: nil) ?? [])
            .filter { $0.lastPathComponent.localizedCaseInsensitiveContains("Min") }
        let maxURLs = (bundle.urls(forResourcesWithExtension: "xml", subdirectory: nil) ?? [])
            .filter { $0.lastPathComponent.localizedCaseInsensitiveContains("Max") }
        self.init(minURLs: minURLs, maxURLs: maxURLs)
    }

    /// Load every Min/Max XML file in `terrainDirectory`, merge them, and write
    /// `Production_Min.xml` / `Production_Max.xml` back into that tree.
    @discardableResult
    static func generateProductionLimits(in terrainDirectory: URL) throws -> (minURL: URL, maxURL: URL) {
        let merger = try TerrainLimitsMerger(terrainDirectory: terrainDirectory)
        return try merger.writeAggregated(to: terrainDirectory)
    }

    @discardableResult
    func writeAggregated(to terrainDirectory: URL) throws -> (minURL: URL, maxURL: URL) {
        guard let aggregatedMin else { throw TerrainLimitsMergerError.noFilesLoaded(kind: "Min") }
        guard let aggregatedMax else { throw TerrainLimitsMergerError.noFilesLoaded(kind: "Max") }

        let minDirectory = terrainDirectory.appendingPathComponent("Min", isDirectory: true)
        let maxDirectory = terrainDirectory.appendingPathComponent("Max", isDirectory: true)
        try FileManager.default.createDirectory(at: minDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: maxDirectory, withIntermediateDirectories: true)

        let minURL = minDirectory.appendingPathComponent("Production_Min.xml")
        let maxURL = maxDirectory.appendingPathComponent("Production_Max.xml")

        do {
            try NMSPropertySerializer.writeMin(aggregatedMin, to: minURL)
            try NMSPropertySerializer.writeMax(aggregatedMax, to: maxURL)
        } catch {
            throw TerrainLimitsMergerError.writeFailed(minURL, error)
        }

        return (minURL, maxURL)
    }

    private static func loadTerrainMin(from url: URL) -> Result<TkVoxelGeneratorData, Error> {
        Result {
            let doc = try parse(xml: url)
            let terrain = try decoder.decode(TerrainMin.self, from: doc.root)
            return terrain.min
        }
    }

    private static func loadTerrainMax(from url: URL) -> Result<TkVoxelGeneratorData, Error> {
        Result {
            let doc = try parse(xml: url)
            let terrain = try decoder.decode(TerrainMax.self, from: doc.root)
            return terrain.max
        }
    }

    private static func parse(xml url: URL) throws -> Document {
        let xmlStr = try String(contentsOf: url, encoding: .utf8)
        return try XMLParser().parse(xmlStr)
    }

    public func aggregate(_ values: [TkVoxelGeneratorData], direction: MergeDirection) -> TkVoxelGeneratorData? {
        guard let first = values.first else { return nil }
        return values.dropFirst().reduce(first) { $0.merged(with: $1, direction: direction) }
    }
}

// MARK: - Merge helpers

private func merge<T: Comparable>(_ lhs: T, _ rhs: T, direction: MergeDirection) -> T {
    direction == .minimum ? Swift.min(lhs, rhs) : Swift.max(lhs, rhs)
}

private func mergeBool(_ lhs: Bool, _ rhs: Bool, direction: MergeDirection) -> Bool {
    direction == .minimum ? (lhs && rhs) : (lhs || rhs)
}

private func mergeString(_ lhs: String, _ rhs: String, direction: MergeDirection) -> String {
    direction == .minimum ? (lhs <= rhs ? lhs : rhs) : (lhs >= rhs ? lhs : rhs)
}

private func mergeOptionalInt(_ lhs: Int?, _ rhs: Int?, direction: MergeDirection) -> Int? {
    switch (lhs, rhs) {
    case (nil, nil): return nil
    case (let value?, nil): return value
    case (nil, let value?): return value
    case (let left?, let right?): return merge(left, right, direction: direction)
    }
}

private func mergeEnum<T: RawRepresentable>(_ lhs: T, _ rhs: T, direction: MergeDirection) -> T
where T.RawValue: Comparable {
    let left = lhs.rawValue
    let right = rhs.rawValue
    let chosen = direction == .minimum ? Swift.min(left, right) : Swift.max(left, right)
    return T(rawValue: chosen) ?? lhs
}

// MARK: - Model merging

private protocol LimitsMergeable {
    func merged(with other: Self, direction: MergeDirection) -> Self
}

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

// MARK: - NMS Property XML serialization

enum NMSPropertySerializer {
    static func writeMin(_ data: TkVoxelGeneratorData, to url: URL) throws {
        try write(rootName: "Min", data: data, to: url)
    }

    static func writeMax(_ data: TkVoxelGeneratorData, to url: URL) throws {
        try write(rootName: "Max", data: data, to: url)
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
