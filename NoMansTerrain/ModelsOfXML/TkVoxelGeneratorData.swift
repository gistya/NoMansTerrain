import Foundation

struct NoiseLayers: Codable {
    var base: TkNoiseUberLayerData
    var hill: TkNoiseUberLayerData
    var mountain: TkNoiseUberLayerData
    var rock: TkNoiseUberLayerData
    var underWater: TkNoiseUberLayerData
    var texture: TkNoiseUberLayerData
    var elevation: TkNoiseUberLayerData
    var continent: TkNoiseUberLayerData

    enum CodingKeys: String, CodingKey {
        case base = "Base"
        case hill = "Hill"
        case mountain = "Mountain"
        case rock = "Rock"
        case underWater = "UnderWater"
        case texture = "Texture"
        case elevation = "Elevation"
        case continent = "Continent"
    }
}

struct GridLayers: Codable {
    var small: TkNoiseGridData
    var large: TkNoiseGridData
    var resourcesHeridium: TkNoiseGridData
    var resourcesIridium: TkNoiseGridData
    var resourcesCopper: TkNoiseGridData
    var resourcesNickel: TkNoiseGridData
    var resourcesAluminium: TkNoiseGridData
    var resourcesGold: TkNoiseGridData
    var resourcesEmeril: TkNoiseGridData

    enum CodingKeys: String, CodingKey {
        case small = "Small"
        case large = "Large"
        case resourcesHeridium = "Resources_Heridium"
        case resourcesIridium = "Resources_Iridium"
        case resourcesCopper = "Resources_Copper"
        case resourcesNickel = "Resources_Nickel"
        case resourcesAluminium = "Resources_Aluminium"
        case resourcesGold = "Resources_Gold"
        case resourcesEmeril = "Resources_Emeril"
    }
}

struct Features: Codable {
    var river: TkNoiseFeatureData
    var crater: TkNoiseFeatureData
    var arches: TkNoiseFeatureData
    var archesSmall: TkNoiseFeatureData
    var blobs: TkNoiseFeatureData
    var blobsSmall: TkNoiseFeatureData
    var substance: TkNoiseFeatureData

    enum CodingKeys: String, CodingKey {
        case river = "River"
        case crater = "Crater"
        case arches = "Arches"
        case archesSmall = "ArchesSmall"
        case blobs = "Blobs"
        case blobsSmall = "BlobsSmall"
        case substance = "Substance"
    }
}

struct Caves: Codable {
    var underground: TkNoiseCaveData

    enum CodingKeys: String, CodingKey {
        case underground = "Underground"
    }
}

/// BaseSeed decodes plain integers, `NONE`, or nested `GcSeed` property bags from NMS XML.
struct BaseSeed: Codable, Equatable {
    var seed: Int?

    init(seed: Int?) {
        self.seed = seed
    }

    init(from decoder: any Decoder) throws {
        struct GcSeed: Decodable {
            var seed: Int
            enum CodingKeys: String, CodingKey { case seed = "Seed" }
        }

        if let nested = try? GcSeed(from: decoder) {
            seed = nested.seed
            return
        }

        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            seed = intVal
            return
        }

        let str = try container.decode(String.self)
        if str.uppercased() == "NONE" {
            seed = nil
        } else if let intVal = Int(str) {
            seed = intVal
        } else {
            seed = nil
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        if let seed {
            try container.encode(seed)
        } else {
            try container.encode("NONE")
        }
    }
}

struct TkVoxelGeneratorData: Codable {
    var baseSeed: BaseSeed
    var seaLevel: Double
    var beachHeight: Double
    var noSeaBaseLevel: Double
    var buildingVoxelType: TkNoiseVoxelTypeEnum
    var resourceVoxelType: TkNoiseVoxelTypeEnum
    var noiseLayers: NoiseLayers
    var gridLayers: GridLayers
    var features: Features
    var caves: Caves
    var minimumCaveDepth: Double
    var caveRoofSmoothingDist: Double
    var maximumSeaLevelCaveDepth: Double
    var buildingTextureRadius: Double
    var buildingSmoothingRadius: Double
    var buildingSmoothingHeight: Double
    var waterFadeInDistance: Double

    enum CodingKeys: String, CodingKey {
        case baseSeed = "BaseSeed"
        case seaLevel = "SeaLevel"
        case beachHeight = "BeachHeight"
        case noSeaBaseLevel = "NoSeaBaseLevel"
        case buildingVoxelType = "BuildingVoxelType"
        case resourceVoxelType = "ResourceVoxelType"
        case noiseLayers = "NoiseLayers"
        case gridLayers = "GridLayers"
        case features = "Features"
        case caves = "Caves"
        case minimumCaveDepth = "MinimumCaveDepth"
        case caveRoofSmoothingDist = "CaveRoofSmoothingDist"
        case maximumSeaLevelCaveDepth = "MaximumSeaLevelCaveDepth"
        case buildingTextureRadius = "BuildingTextureRadius"
        case buildingSmoothingRadius = "BuildingSmoothingRadius"
        case buildingSmoothingHeight = "BuildingSmoothingHeight"
        case waterFadeInDistance = "WaterFadeInDistance"
    }
}

/// Root wrapper for Min terrain XML files (e.g. Alien_Min.xml).
struct TerrainMinDocument: Codable {
    var min: TkVoxelGeneratorData

    enum CodingKeys: String, CodingKey {
        case min = "Min"
    }
}
