public nonisolated struct TerrainMin: Codable, Sendable {
    public var min: TkVoxelGeneratorData

    public init(min: TkVoxelGeneratorData) { self.min = min }

    enum CodingKeys: String, CodingKey {
        case min = "Min"
    }
}

public nonisolated struct TerrainMax: Codable, Sendable {
    public var max: TkVoxelGeneratorData

    public init(max: TkVoxelGeneratorData) { self.max = max }

    enum CodingKeys: String, CodingKey {
        case max = "Max"
    }
}
