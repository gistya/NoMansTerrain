import Foundation

public typealias BuildingVoxelType = NoiseVoxelType
public typealias ResourceVoxelType = NoiseVoxelType

public enum NoiseVoxelType: String, Codable, CaseIterable {
    case base = "Base"
    case rock = "Rock"
    case mountain = "Mountain"
    case sand = "Sand"
    case cave = "Cave"
    case substance1 = "Substance_1"
    case substance2 = "Substance_2"
    case substance3 = "Substance_3"
    case randomRock = "RandomRock"
    case randomRockOrSubstance = "RandomRockOrSubstance"
}

public enum OffsetType: String, Codable, CaseIterable {
    case base = "Base"
    case all = "All"
    case zero = "Zero"
    case seaLevel = "SeaLevel"
}

public enum WaterFadeType: String, Codable, CaseIterable {
    case none = "None"
    case above = "Above"
    case below = "Below"
}

public enum DebugNoiseType: String, Codable, CaseIterable {
    case uber = "Uber"
    case plane = "Plane"
    case check = "Check"
    case sine = "Sine"
}

public enum NoiseGridType: String, Codable, CaseIterable {
    case superFormula01 = "SuperFormula_01"
    case superFormula02 = "SuperFormula_02"
    case superFormula03 = "SuperFormula_03"
    case superFormula04 = "SuperFormula_04"
    case superFormula05 = "SuperFormula_05"
    case superFormula06 = "SuperFormula_06"
    case superFormula07 = "SuperFormula_07"
    case superFormula08 = "SuperFormula_08"
    case superPrimitiveRandom = "SuperPrimitiveRandom"
    case superFormulaRandom = "SuperFormulaRandom"
    case superFormula = "SuperFormula"
    case superPrimitive = "SuperPrimitive"
    case sphere = "Sphere"
    case cube = "Cube"
    case cone = "Cone"
    case torus = "Torus"
    case cylinder = "Cylinder"
    case capsule = "Capsule"
    case corridor = "Corridor"
    case pipe = "Pipe"
    case puck = "Puck"
    case file = "File"
}

public extension NoiseGridType {
    /// True for the SuperFormula-driven grid types (the ones whose SuperFormula 1/2
    /// settings actually matter).
    public var isSuperFormula: Bool {
        switch self {
        case .superFormula, .superFormula01, .superFormula02, .superFormula03, .superFormula04,
             .superFormula05, .superFormula06, .superFormula07, .superFormula08, .superFormulaRandom:
            return true
        default:
            return false
        }
    }
}

public enum FeatureType: String, Codable, CaseIterable {
    case tube = "Tube"
    case blob = "Blob"
}
