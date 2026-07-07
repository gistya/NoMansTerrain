import Foundation

public struct NoiseLayers: Codable, Equatable, Sendable {
    public var base: TkNoiseUberLayerData
    public var hill: TkNoiseUberLayerData
    public var mountain: TkNoiseUberLayerData
    public var rock: TkNoiseUberLayerData
    public var underWater: TkNoiseUberLayerData
    public var texture: TkNoiseUberLayerData
    public var elevation: TkNoiseUberLayerData
    public var continent: TkNoiseUberLayerData

    public enum CodingKeys: String, CodingKey {
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

public struct GridLayers: Codable, Equatable, Sendable {
    public var small: TkNoiseGridData
    public var large: TkNoiseGridData
    public var resourcesHeridium: TkNoiseGridData
    public var resourcesIridium: TkNoiseGridData
    public var resourcesCopper: TkNoiseGridData
    public var resourcesNickel: TkNoiseGridData
    public var resourcesAluminium: TkNoiseGridData
    public var resourcesGold: TkNoiseGridData
    public var resourcesEmeril: TkNoiseGridData

    public enum CodingKeys: String, CodingKey {
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

public struct Features: Codable, Equatable, Sendable {
    public var river: TkNoiseFeatureData
    public var crater: TkNoiseFeatureData
    public var arches: TkNoiseFeatureData
    public var archesSmall: TkNoiseFeatureData
    public var blobs: TkNoiseFeatureData
    public var blobsSmall: TkNoiseFeatureData
    public var substance: TkNoiseFeatureData

    public enum CodingKeys: String, CodingKey {
        case river = "River"
        case crater = "Crater"
        case arches = "Arches"
        case archesSmall = "ArchesSmall"
        case blobs = "Blobs"
        case blobsSmall = "BlobsSmall"
        case substance = "Substance"
    }
}

public struct Caves: Codable, Equatable, Sendable {
    public var underground: TkNoiseCaveData

    public enum CodingKeys: String, CodingKey {
        case underground = "Underground"
    }
}

/// BaseSeed decodes plain integers, `NONE`, or nested `GcSeed` property bags from NMS XML.
public struct BaseSeed: Codable, Equatable, Sendable {
    public var seed: Int?

    public init(seed: Int?) {
        self.seed = seed
    }

    public init(from decoder: any Decoder) throws {
        struct GcSeed: Decodable, Sendable {
            public var seed: Int
            public enum CodingKeys: String, CodingKey { case seed = "Seed" }
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

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        if let seed {
            try container.encode(seed)
        } else {
            try container.encode("NONE")
        }
    }
}

public struct TkVoxelGeneratorData: Codable, Equatable, Sendable {
    public var baseSeed: BaseSeed
    public var seaLevel: Double
    public var beachHeight: Double
    public var noSeaBaseLevel: Double
    public var buildingVoxelType: TkNoiseVoxelTypeEnum
    public var resourceVoxelType: TkNoiseVoxelTypeEnum
    public var noiseLayers: NoiseLayers
    public var gridLayers: GridLayers
    public var features: Features
    public var caves: Caves
    public var minimumCaveDepth: Double
    public var caveRoofSmoothingDist: Double
    public var maximumSeaLevelCaveDepth: Double
    public var buildingTextureRadius: Double
    public var buildingSmoothingRadius: Double
    public var buildingSmoothingHeight: Double
    public var waterFadeInDistance: Double

    public init(
        baseSeed: BaseSeed,
        seaLevel: Double,
        beachHeight: Double,
        noSeaBaseLevel: Double,
        buildingVoxelType: TkNoiseVoxelTypeEnum,
        resourceVoxelType: TkNoiseVoxelTypeEnum,
        noiseLayers: NoiseLayers,
        gridLayers: GridLayers,
        features: Features,
        caves: Caves,
        minimumCaveDepth: Double,
        caveRoofSmoothingDist: Double,
        maximumSeaLevelCaveDepth: Double,
        buildingTextureRadius: Double,
        buildingSmoothingRadius: Double,
        buildingSmoothingHeight: Double,
        waterFadeInDistance: Double
    ) {
        self.baseSeed = baseSeed
        self.seaLevel = seaLevel
        self.beachHeight = beachHeight
        self.noSeaBaseLevel = noSeaBaseLevel
        self.buildingVoxelType = buildingVoxelType
        self.resourceVoxelType = resourceVoxelType
        self.noiseLayers = noiseLayers
        self.gridLayers = gridLayers
        self.features = features
        self.caves = caves
        self.minimumCaveDepth = minimumCaveDepth
        self.caveRoofSmoothingDist = caveRoofSmoothingDist
        self.maximumSeaLevelCaveDepth = maximumSeaLevelCaveDepth
        self.buildingTextureRadius = buildingTextureRadius
        self.buildingSmoothingRadius = buildingSmoothingRadius
        self.buildingSmoothingHeight = buildingSmoothingHeight
        self.waterFadeInDistance = waterFadeInDistance
    }

    public enum CodingKeys: String, CodingKey {
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
public struct TerrainMinDocument: Codable, Equatable, Sendable {
    public var min: TkVoxelGeneratorData

    public enum CodingKeys: String, CodingKey {
        case min = "Min"
    }
}
