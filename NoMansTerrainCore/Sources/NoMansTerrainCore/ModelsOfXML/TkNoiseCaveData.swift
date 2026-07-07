import Foundation

public struct TkNoiseCaveData: Codable, Equatable, Sendable {
    public var mouth: TkNoiseFeatureData
    public var tunnel: TkNoiseFeatureData

    public enum CodingKeys: String, CodingKey {
        case mouth = "Mouth"
        case tunnel = "Tunnel"
    }
}
