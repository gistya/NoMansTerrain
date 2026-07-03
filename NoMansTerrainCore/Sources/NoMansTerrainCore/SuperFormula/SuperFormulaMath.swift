// Apple-only: uses `simd`, which isn't available on Windows/Linux. The SuperFormula editor
// is a macOS-only feature, so this compiles to nothing off Apple platforms.
#if canImport(simd)
import Foundation
import simd

public enum SuperFormulaMath {
    /// Gielis superformula radius for angle `angle` (radians).
    public static func radius(
        angle: Double,
        m: Double,
        n1: Double,
        n2: Double,
        n3: Double
    ) -> Double {
        let safeN1 = max(n1, 0.001)
        let safeN2 = max(abs(n2), 0.001)
        let safeN3 = max(abs(n3), 0.001)
        let quarter = m * angle / 4.0
        let cosTerm = abs(cos(quarter))
        let sinTerm = abs(sin(quarter))
        let base = pow(cosTerm, safeN2) + pow(sinTerm, safeN3)
        guard base > 1e-8 else { return 0 }
        return pow(base, -1.0 / safeN1)
    }

    /// Spherical 3D superformula using two NMS formula parameter sets. (SuperPrimitive is
    /// a separate thing in-game and is intentionally not combined with the superformula.)
    public static func sample(
        theta: Double,
        phi: Double,
        formula1: TkNoiseSuperFormulaData,
        formula2: TkNoiseSuperFormulaData
    ) -> SIMD3<Float> {
        let rTheta = radius(
            angle: theta,
            m: formula1.formM,
            n1: formula1.formN1,
            n2: formula1.formN2,
            n3: formula1.formN3
        )
        let rPhi = radius(
            angle: phi - .pi / 2,
            m: formula2.formM,
            n1: formula2.formN1,
            n2: formula2.formN2,
            n3: formula2.formN3
        )

        let r = rTheta * rPhi
        let sinPhi = sin(phi)
        let position = SIMD3<Double>(
            r * cos(theta) * sinPhi,
            r * sin(theta) * sinPhi,
            r * cos(phi)
        )

        return SIMD3<Float>(Float(position.x), Float(position.y), Float(position.z))
    }
}
#endif