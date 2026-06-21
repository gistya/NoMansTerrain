import Foundation

struct TkNoiseOffsetEnum: Codable, Equatable {
    var offsetType: OffsetType

    enum CodingKeys: String, CodingKey {
        case offsetType = "OffsetType"
    }
}