import Foundation

public struct TkNoiseSuperFormulaData: Codable, Equatable, Sendable {
    /// 0.0990...9.9990
    public var formM: Double
    /// 0.0...99.90
    public var formN1: Double
    /// -49.5...100.5
    public var formN2: Double
    /// -49.5...100.5
    public var formN3: Double

    public init(formM: Double, formN1: Double, formN2: Double, formN3: Double) {
        self.formM = formM
        self.formN1 = formN1
        self.formN2 = formN2
        self.formN3 = formN3
    }

    public enum CodingKeys: String, CodingKey {
        case formM = "Form_m"
        case formN1 = "Form_n1"
        case formN2 = "Form_n2"
        case formN3 = "Form_n3"
    }
}
