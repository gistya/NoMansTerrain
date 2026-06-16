import Foundation

struct TkNoiseOffsetEnum: Codable {
    var offsetType: OffsetType

    enum CodingKeys: String, CodingKey {
        case offsetType = "OffsetType"
    }
}