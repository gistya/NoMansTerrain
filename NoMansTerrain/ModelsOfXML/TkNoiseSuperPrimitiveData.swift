import Foundation

struct TkNoiseSuperPrimitiveData: Codable, Equatable {
    /// 0.0990...1.0
    var width: Double
    /// 0.0990...1.0
    var height: Double
    /// 0.0990...1.0
    var depth: Double
    /// 0.0990...1.0
    var thickness: Double
    /// 0.0...1.0
    var cornerRadiusXY: Double
    /// 0.0...1.0
    var cornerRadiusZ: Double
    /// 0.0...1.0
    var bottomRadiusOffset: Double

    enum CodingKeys: String, CodingKey {
        case width = "Width"
        case height = "Height"
        case depth = "Depth"
        case thickness = "Thickness"
        case cornerRadiusXY = "CornerRadiusXY"
        case cornerRadiusZ = "CornerRadiusZ"
        case bottomRadiusOffset = "BottomRadiusOffset"
    }
}
