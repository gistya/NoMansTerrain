import Foundation

struct TkNoiseVoxelTypeEnum: Codable, Equatable {
    var noiseVoxelType: NoiseVoxelType

    enum CodingKeys: String, CodingKey {
        case noiseVoxelType = "NoiseVoxelType"
    }
}