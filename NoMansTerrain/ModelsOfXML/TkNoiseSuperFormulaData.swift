import Foundation

struct TkNoiseSuperFormulaData: Codable, Equatable {
    /// 0.0990...9.9990
    var formM: Double
    /// 0.0...99.90
    var formN1: Double
    /// -49.5...100.5
    var formN2: Double
    /// -49.5...100.5
    var formN3: Double

    enum CodingKeys: String, CodingKey {
        case formM = "Form_m"
        case formN1 = "Form_n1"
        case formN2 = "Form_n2"
        case formN3 = "Form_n3"
    }
}
