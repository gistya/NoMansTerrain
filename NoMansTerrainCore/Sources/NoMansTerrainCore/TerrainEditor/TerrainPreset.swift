import Foundation

public struct TerrainPreset: Codable, Hashable, Identifiable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable {
        case alien
        case alpine
        case caverns
        case craters
        case desert
        case floatingIslands
        case grandCanyon
        case hugeArches
        case lilyPad
        case mountainRavines
        case waterworld
        
        public var displayName: String {
            switch self {
            case .alien: "Alien"
            case .alpine: "Alpine"
            case .caverns: "Caverns"
            case .craters: "Craters"
            case .desert: "Desert"
            case .floatingIslands: "Floating Islands"
            case .grandCanyon: "Grand Canyon"
            case .hugeArches: "Huge Arches"
            case .lilyPad: "Lily Pad"
            case .mountainRavines: "Mountain Ravines"
            case .waterworld: "Water World"
            }
        }

        public var filePrefix: String {
            switch self {
            case .alien: "Alien"
            case .alpine: "Alpine"
            case .caverns: "Caverns"
            case .craters: "Craters"
            case .desert: "Desert"
            case .floatingIslands: "FloatingIslands"
            case .grandCanyon: "GrandCanyon"
            case .hugeArches: "HugeArches"
            case .lilyPad: "LilyPad"
            case .mountainRavines: "MountainRavines"
            case .waterworld: "Waterworld"
            }
        }
    }
    
    public var order: Int {
        switch (kind, category) {
            case (.floatingIslands, .standard): 0
            case (.grandCanyon,     .standard): 1
            case (.mountainRavines, .standard): 2
            case (.hugeArches,      .standard): 3
            case (.alien,           .standard): 4
            case (.craters,         .standard): 5
            case (.caverns,         .standard): 6
            case (.alpine,          .standard): 7
            case (.lilyPad,         .standard): 8
            case (.desert,          .standard): 9
            case (.waterworld,      .prime)   : 10
            case (.floatingIslands, .prime)   : 11
            case (.grandCanyon,     .prime)   : 12
            case (.mountainRavines, .prime)   : 13
            case (.hugeArches,      .prime)   : 14
            case (.alien,           .prime)   : 15
            case (.craters,         .prime)   : 16
            case (.caverns,         .prime)   : 17
            case (.alpine,          .prime)   : 18
            case (.lilyPad,         .prime)   : 19
            case (.desert,          .prime)   : 20
            case (.floatingIslands, .purple)  : 21
            case (.grandCanyon,     .purple)  : 22
            case (.mountainRavines, .purple)  : 23
            case (.hugeArches,      .purple)  : 24
            case (.alien,           .purple)  : 25
            case (.craters,         .purple)  : 26
            case (.caverns,         .purple)  : 27
            case (.alpine,          .purple)  : 28
            case (.lilyPad,         .purple)  : 29
            case (.desert,          .purple)  : 30
        default:
            -1
        }
    }

    public var kind: Kind
    public var category: Terrain.Category

    public init(kind: Kind, category: Terrain.Category) {
        self.kind = kind
        self.category = category
    }

    public var id: String { fileBaseName }

    public var fileBaseName: String {
        switch category {
        case .standard: kind.filePrefix
        case .prime: kind.filePrefix + Terrain.Category.prime.rawValue
        case .purple: kind.filePrefix + Terrain.Category.purple.rawValue
        }
    }

    public var minFileName: String { "\(fileBaseName)_Min.xml" }
    public var maxFileName: String { "\(fileBaseName)_Max.xml" }

    public var displayName: String {
        switch category {
        case .standard: kind.displayName
        case .prime: "\(kind.displayName) Prime"
        case .purple: "\(kind.displayName) Purple"
        }
    }

    public var minTerrain: Terrain { terrain(limit: .min) }
    public var maxTerrain: Terrain { terrain(limit: .max) }

    private func terrain(limit: Terrain.Limit) -> Terrain {
        switch kind {
        case .alien: .alien(category, limit)
        case .alpine: .alpine(category, limit)
        case .caverns: .caverns(category, limit)
        case .craters: .craters(category, limit)
        case .desert: .desert(category, limit)
        case .floatingIslands: .floatingIslands(category, limit)
        case .grandCanyon: .grandCanyon(category, limit)
        case .hugeArches: .hugeArches(category, limit)
        case .lilyPad: .lilyPad(category, limit)
        case .mountainRavines: .mountainRavines(category, limit)
        case .waterworld: .waterworld(category, limit)
        }
    }

    public static var all: [TerrainPreset] {
        Kind.allCases.flatMap { kind in
            guard kind != .waterworld else { return [TerrainPreset(kind: kind, category: .prime)]}
            return [Terrain.Category.standard, .prime, .purple]
                .map { category in TerrainPreset(kind: kind, category: category)}
        } .sorted { a, b in a.order < b.order }
    }
}

