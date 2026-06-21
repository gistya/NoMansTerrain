import Foundation

struct TkNoiseCaveData: Codable, Equatable {
    var mouth: TkNoiseFeatureData
    var tunnel: TkNoiseFeatureData

    enum CodingKeys: String, CodingKey {
        case mouth = "Mouth"
        case tunnel = "Tunnel"
    }
}