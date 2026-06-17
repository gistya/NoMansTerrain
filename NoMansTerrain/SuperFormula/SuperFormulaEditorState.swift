import Foundation
import Observation
import SwiftUI
import simd

@MainActor
@Observable
final class SuperFormulaEditorState {
    var formula1 = TkNoiseSuperFormulaData(formM: 5, formN1: 2, formN2: 6, formN3: 6)
    var formula2 = TkNoiseSuperFormulaData(formM: 4, formN1: 1, formN2: 1, formN3: 1)
    var primitive = TkNoiseSuperPrimitiveData(
        width: 1,
        height: 1,
        depth: 1,
        thickness: 1,
        cornerRadiusXY: 0,
        cornerRadiusZ: 0,
        bottomRadiusOffset: 0
    )

    var cameraAzimuth: Float = 0.6
    var cameraElevation: Float = 0.35
    var cameraDistance: Float = 3.2

    var mesh: SuperFormulaMesh {
        SuperFormulaMesh.generate(
            formula1: formula1,
            formula2: formula2,
            primitive: primitive
        )
    }

    var meshSignature: String {
        [
            formula1.formM, formula1.formN1, formula1.formN2, formula1.formN3,
            formula2.formM, formula2.formN1, formula2.formN2, formula2.formN3,
            primitive.width, primitive.height, primitive.depth, primitive.thickness,
            primitive.cornerRadiusXY, primitive.cornerRadiusZ, primitive.bottomRadiusOffset
        ]
        .map { String(format: "%.4f", $0) }
        .joined(separator: "|")
    }

    var xmlSnippet: String {
        """
        <Property name="SuperFormula1" value="TkNoiseSuperFormulaData">
        \t<Property name="Form_m" value="\(format(formula1.formM))" />
        \t<Property name="Form_n1" value="\(format(formula1.formN1))" />
        \t<Property name="Form_n2" value="\(format(formula1.formN2))" />
        \t<Property name="Form_n3" value="\(format(formula1.formN3))" />
        </Property>
        <Property name="SuperFormula2" value="TkNoiseSuperFormulaData">
        \t<Property name="Form_m" value="\(format(formula2.formM))" />
        \t<Property name="Form_n1" value="\(format(formula2.formN1))" />
        \t<Property name="Form_n2" value="\(format(formula2.formN2))" />
        \t<Property name="Form_n3" value="\(format(formula2.formN3))" />
        </Property>
        <Property name="SuperPrimitive" value="TkNoiseSuperPrimitiveData">
        \t<Property name="Width" value="\(format(primitive.width))" />
        \t<Property name="Height" value="\(format(primitive.height))" />
        \t<Property name="Depth" value="\(format(primitive.depth))" />
        \t<Property name="Thickness" value="\(format(primitive.thickness))" />
        \t<Property name="CornerRadiusXY" value="\(format(primitive.cornerRadiusXY))" />
        \t<Property name="CornerRadiusZ" value="\(format(primitive.cornerRadiusZ))" />
        \t<Property name="BottomRadiusOffset" value="\(format(primitive.bottomRadiusOffset))" />
        </Property>
        """
    }

    var formula1Binding: Binding<TkNoiseSuperFormulaData> {
        Binding(
            get: { self.formula1 },
            set: { self.formula1 = $0 }
        )
    }

    var formula2Binding: Binding<TkNoiseSuperFormulaData> {
        Binding(
            get: { self.formula2 },
            set: { self.formula2 = $0 }
        )
    }

    var primitiveBinding: Binding<TkNoiseSuperPrimitiveData> {
        Binding(
            get: { self.primitive },
            set: { self.primitive = $0 }
        )
    }

    func applyPreset(_ preset: SuperFormulaPreset) {
        formula1 = preset.formula1
        formula2 = preset.formula2
        primitive = preset.primitive
    }

    private func format(_ value: Double) -> String {
        String(format: "%.6f", value)
    }
}

struct SuperFormulaPreset: Identifiable {
    let id: String
    let name: String
    let formula1: TkNoiseSuperFormulaData
    let formula2: TkNoiseSuperFormulaData
    let primitive: TkNoiseSuperPrimitiveData

    static let defaults: [SuperFormulaPreset] = [
        SuperFormulaPreset(
            id: "alien",
            name: "Alien Min",
            formula1: TkNoiseSuperFormulaData(formM: 5, formN1: 2, formN2: 6, formN3: 6),
            formula2: TkNoiseSuperFormulaData(formM: 4, formN1: 1, formN2: 1, formN3: 1),
            primitive: TkNoiseSuperPrimitiveData(
                width: 1, height: 1, depth: 1, thickness: 1,
                cornerRadiusXY: 0, cornerRadiusZ: 0, bottomRadiusOffset: 0
            )
        ),
        SuperFormulaPreset(
            id: "star",
            name: "Star",
            formula1: TkNoiseSuperFormulaData(formM: 6, formN1: 0.3, formN2: 0.3, formN3: 0.3),
            formula2: TkNoiseSuperFormulaData(formM: 6, formN1: 0.3, formN2: 0.3, formN3: 0.3),
            primitive: TkNoiseSuperPrimitiveData(
                width: 1, height: 1, depth: 1, thickness: 1,
                cornerRadiusXY: 0, cornerRadiusZ: 0, bottomRadiusOffset: 0
            )
        ),
        SuperFormulaPreset(
            id: "flower",
            name: "Flower",
            formula1: TkNoiseSuperFormulaData(formM: 8, formN1: 1, formN2: 1, formN3: 8),
            formula2: TkNoiseSuperFormulaData(formM: 1, formN1: 1, formN2: 1, formN3: 1),
            primitive: TkNoiseSuperPrimitiveData(
                width: 1, height: 1.2, depth: 1, thickness: 0.8,
                cornerRadiusXY: 0.2, cornerRadiusZ: 0.1, bottomRadiusOffset: 0
            )
        ),
        SuperFormulaPreset(
            id: "asteroid",
            name: "Asteroid",
            formula1: TkNoiseSuperFormulaData(formM: 3, formN1: 4, formN2: 4, formN3: 4),
            formula2: TkNoiseSuperFormulaData(formM: 2, formN1: 5, formN2: 5, formN3: 5),
            primitive: TkNoiseSuperPrimitiveData(
                width: 1.1, height: 0.8, depth: 1.2, thickness: 0.7,
                cornerRadiusXY: 0.35, cornerRadiusZ: 0.25, bottomRadiusOffset: 0.15
            )
        )
    ]
}