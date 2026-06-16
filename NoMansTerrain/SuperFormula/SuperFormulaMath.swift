import Foundation
import simd

enum SuperFormulaMath {
    /// Gielis superformula radius for angle `angle` (radians).
    static func radius(
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

    /// Spherical 3D superformula using two NMS formula parameter sets.
    static func sample(
        theta: Double,
        phi: Double,
        formula1: TkNoiseSuperFormulaData,
        formula2: TkNoiseSuperFormulaData,
        primitive: TkNoiseSuperPrimitiveData
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

        var r = rTheta * rPhi

        if phi > .pi / 2 {
            r *= 1.0 + primitive.bottomRadiusOffset
        }

        let shell = max(0.15, primitive.thickness)
        r *= shell

        let sinPhi = sin(phi)
        var position = SIMD3<Double>(
            r * cos(theta) * sinPhi,
            r * sin(theta) * sinPhi,
            r * cos(phi)
        )

        position.x *= primitive.width
        position.y *= primitive.height
        position.z *= primitive.depth

        if primitive.cornerRadiusXY > 0 || primitive.cornerRadiusZ > 0 {
            let xyRadius = hypot(position.x, position.y)
            let corner = primitive.cornerRadiusXY * 0.35
            if xyRadius > 1e-6 {
                let softened = xyRadius * (1.0 - corner) + corner * tanh(xyRadius / max(corner, 0.01))
                let scale = softened / xyRadius
                position.x *= scale
                position.y *= scale
            }
            let zCorner = primitive.cornerRadiusZ * 0.35
            position.z *= 1.0 - zCorner + zCorner * tanh(abs(position.z))
        }

        return SIMD3<Float>(Float(position.x), Float(position.y), Float(position.z))
    }
}