import Foundation

public struct TkNoiseVoxelTypeEnum: Codable, Equatable {
    public var noiseVoxelType: NoiseVoxelType

    public enum CodingKeys: String, CodingKey {
        case noiseVoxelType = "NoiseVoxelType"
    }
}