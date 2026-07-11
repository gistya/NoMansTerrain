#if canImport(simd)
import Foundation
import simd

public struct SuperFormulaVertex {
    public var position: SIMD3<Float>
    public var normal: SIMD3<Float>
}

public struct SuperFormulaMesh {
    public var vertices: [SuperFormulaVertex]
    public var indices: [UInt32]

    public static let thetaSegments = 96
    public static let phiSegments = 64

    public static func generate(
        formula1: TkNoiseSuperFormulaData,
        formula2: TkNoiseSuperFormulaData
    ) -> SuperFormulaMesh {
        var positions: [SIMD3<Float>] = []
        positions.reserveCapacity((thetaSegments + 1) * (phiSegments + 1))

        for phiIndex in 0...phiSegments {
            let phi = Double(phiIndex) / Double(phiSegments) * .pi
            for thetaIndex in 0...thetaSegments {
                let theta = Double(thetaIndex) / Double(thetaSegments) * 2.0 * .pi
                positions.append(
                    SuperFormulaMath.sample(
                        theta: theta,
                        phi: phi,
                        formula1: formula1,
                        formula2: formula2
                    )
                )
            }
        }

        var vertices: [SuperFormulaVertex] = []
        vertices.reserveCapacity(positions.count)

        let columns = thetaSegments + 1
        for phiIndex in 0...phiSegments {
            for thetaIndex in 0...thetaSegments {
                let index = phiIndex * columns + thetaIndex
                let normal = estimateNormal(
                    positions: positions,
                    phiIndex: phiIndex,
                    thetaIndex: thetaIndex,
                    columns: columns,
                    rows: phiSegments + 1
                )
                vertices.append(SuperFormulaVertex(position: positions[index], normal: normal))
            }
        }

        var indices: [UInt32] = []
        indices.reserveCapacity(thetaSegments * phiSegments * 6)

        for phiIndex in 0..<phiSegments {
            for thetaIndex in 0..<thetaSegments {
                let topLeft = UInt32(phiIndex * columns + thetaIndex)
                let topRight = topLeft + 1
                let bottomLeft = UInt32((phiIndex + 1) * columns + thetaIndex)
                let bottomRight = bottomLeft + 1

                indices.append(topLeft)
                indices.append(bottomLeft)
                indices.append(topRight)

                indices.append(topRight)
                indices.append(bottomLeft)
                indices.append(bottomRight)
            }
        }

        return SuperFormulaMesh(vertices: vertices, indices: indices)
    }

    private static func estimateNormal(
        positions: [SIMD3<Float>],
        phiIndex: Int,
        thetaIndex: Int,
        columns: Int,
        rows: Int
    ) -> SIMD3<Float> {
        let index = phiIndex * columns + thetaIndex
        let center = positions[index]

        let left = positions[index + (thetaIndex > 0 ? -1 : columns - 1)]
        let right = positions[index + (thetaIndex < columns - 1 ? 1 : -(columns - 1))]
        let up = positions[index + (phiIndex > 0 ? -columns : (rows - 1) * columns)]
        let down = positions[index + (phiIndex < rows - 1 ? columns : -(rows - 1) * columns)]

        let tangentU = right - left
        let tangentV = down - up
        let normal = simd_normalize(simd_cross(tangentU, tangentV))
        let facing = simd_dot(normal, center)
        return facing < 0 ? -normal : normal
    }
}
#endif