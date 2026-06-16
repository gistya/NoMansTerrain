struct TerrainMin: Codable {
    var min: TkVoxelGeneratorData
    
    enum CodingKeys: String, CodingKey {
        case min = "Min"
    }
}

struct TerrainMax: Codable {
    var max: TkVoxelGeneratorData
    
    enum CodingKeys: String, CodingKey {
        case max = "Max"
    }
}
