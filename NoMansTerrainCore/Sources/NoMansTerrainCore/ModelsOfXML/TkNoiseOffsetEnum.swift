import Foundation

public struct TkNoiseOffsetEnum: Codable, Equatable, Sendable {
    public var offsetType: OffsetType

    public enum CodingKeys: String, CodingKey {
        case offsetType = "OffsetType"
    }
}
