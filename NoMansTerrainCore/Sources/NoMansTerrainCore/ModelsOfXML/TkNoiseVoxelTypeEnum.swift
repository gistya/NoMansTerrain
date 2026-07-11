import Foundation

public struct TkNoiseVoxelTypeEnum: Codable, Equatable, Sendable {
    public var noiseVoxelType: NoiseVoxelType

    public enum CodingKeys: String, CodingKey {
        case noiseVoxelType = "NoiseVoxelType"
    }
}
