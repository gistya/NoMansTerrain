nonisolated struct TerrainMin: Codable, Sendable {
    var min: TkVoxelGeneratorData
    
    enum CodingKeys: String, CodingKey {
        case min = "Min"
    }
}

nonisolated struct TerrainMax: Codable, Sendable {
    var max: TkVoxelGeneratorData
    
    enum CodingKeys: String, CodingKey {
        case max = "Max"
    }
}
