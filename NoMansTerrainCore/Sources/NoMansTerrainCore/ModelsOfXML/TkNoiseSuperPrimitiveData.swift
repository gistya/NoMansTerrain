import Foundation

public struct TkNoiseSuperPrimitiveData: Codable, Equatable, Sendable {
    /// 0.0990...1.0
    public var width: Double
    /// 0.0990...1.0
    public var height: Double
    /// 0.0990...1.0
    public var depth: Double
    /// 0.0990...1.0
    public var thickness: Double
    /// 0.0...1.0
    public var cornerRadiusXY: Double
    /// 0.0...1.0
    public var cornerRadiusZ: Double
    /// 0.0...1.0
    public var bottomRadiusOffset: Double

    public enum CodingKeys: String, CodingKey {
        case width = "Width"
        case height = "Height"
        case depth = "Depth"
        case thickness = "Thickness"
        case cornerRadiusXY = "CornerRadiusXY"
        case cornerRadiusZ = "CornerRadiusZ"
        case bottomRadiusOffset = "BottomRadiusOffset"
    }
}
