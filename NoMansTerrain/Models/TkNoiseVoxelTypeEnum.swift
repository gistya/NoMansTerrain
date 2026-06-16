import Foundation

struct TkNoiseVoxelTypeEnum: Codable {
    var noiseVoxelType: NoiseVoxelType

    enum CodingKeys: String, CodingKey {
        case noiseVoxelType = "NoiseVoxelType"
    }
}