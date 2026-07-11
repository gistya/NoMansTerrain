import NoMansTerrainCore
import Foundation
import Observation
import SwiftUI
import simd

@MainActor
@Observable
final class SuperFormulaEditorState {
    // Min and Max sets, so a designed shape carries valid Min/Max into the terrain editor.
    var minFormula1 = TkNoiseSuperFormulaData(formM: 5, formN1: 2, formN2: 6, formN3: 6)
    var maxFormula1 = TkNoiseSuperFormulaData(formM: 5, formN1: 2, formN2: 6, formN3: 6)
    var minFormula2 = TkNoiseSuperFormulaData(formM: 4, formN1: 1, formN2: 1, formN3: 1)
    var maxFormula2 = TkNoiseSuperFormulaData(formM: 4, formN1: 1, formN2: 1, formN3: 1)

    /// Which set the sliders edit and the renderer displays.
    var showingMax = false

    var cameraAzimuth: Float = 0.6
    var cameraElevation: Float = 0.35
    var cameraDistance: Float = 3.2

    private var shownFormula1: TkNoiseSuperFormulaData { showingMax ? maxFormula1 : minFormula1 }
    private var shownFormula2: TkNoiseSuperFormulaData { showingMax ? maxFormula2 : minFormula2 }

    var mesh: SuperFormulaMesh {
        SuperFormulaMesh.generate(
            formula1: shownFormula1,
            formula2: shownFormula2
        )
    }

    var meshSignature: String {
        let f1 = shownFormula1, f2 = shownFormula2
        return ([f1.formM, f1.formN1, f1.formN2, f1.formN3, f2.formM, f2.formN1, f2.formN2, f2.formN3]
            .map { String(format: "%.4f", $0) } + [showingMax ? "max" : "min"])
            .joined(separator: "|")
    }

    var xmlSnippet: String {
        let f1 = shownFormula1, f2 = shownFormula2
        return """
        <!-- \(showingMax ? "Max" : "Min") -->
        <Property name="SuperFormula1" value="TkNoiseSuperFormulaData">
        \t<Property name="Form_m" value="\(format(f1.formM))" />
        \t<Property name="Form_n1" value="\(format(f1.formN1))" />
        \t<Property name="Form_n2" value="\(format(f1.formN2))" />
        \t<Property name="Form_n3" value="\(format(f1.formN3))" />
        </Property>
        <Property name="SuperFormula2" value="TkNoiseSuperFormulaData">
        \t<Property name="Form_m" value="\(format(f2.formM))" />
        \t<Property name="Form_n1" value="\(format(f2.formN1))" />
        \t<Property name="Form_n2" value="\(format(f2.formN2))" />
        \t<Property name="Form_n3" value="\(format(f2.formN3))" />
        </Property>
        """
    }

    /// Edits the currently-shown (Min or Max) SuperFormula 1.
    var formula1Binding: Binding<TkNoiseSuperFormulaData> {
        Binding(
            get: { self.showingMax ? self.maxFormula1 : self.minFormula1 },
            set: { if self.showingMax { self.maxFormula1 = $0 } else { self.minFormula1 = $0 } }
        )
    }

    /// Edits the currently-shown (Min or Max) SuperFormula 2.
    var formula2Binding: Binding<TkNoiseSuperFormulaData> {
        Binding(
            get: { self.showingMax ? self.maxFormula2 : self.minFormula2 },
            set: { if self.showingMax { self.maxFormula2 = $0 } else { self.minFormula2 = $0 } }
        )
    }

    /// Applies a preset to the currently-shown (Min or Max) set.
    func applyPreset(_ preset: SuperFormulaPreset) {
        if showingMax {
            maxFormula1 = preset.formula1
            maxFormula2 = preset.formula2
        } else {
            minFormula1 = preset.formula1
            minFormula2 = preset.formula2
        }
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

    static let defaults: [SuperFormulaPreset] = [
        SuperFormulaPreset(
            id: "alien",
            name: "Alien Min",
            formula1: TkNoiseSuperFormulaData(formM: 5, formN1: 2, formN2: 6, formN3: 6),
            formula2: TkNoiseSuperFormulaData(formM: 4, formN1: 1, formN2: 1, formN3: 1)
        ),
        SuperFormulaPreset(
            id: "star",
            name: "Star",
            formula1: TkNoiseSuperFormulaData(formM: 6, formN1: 0.3, formN2: 0.3, formN3: 0.3),
            formula2: TkNoiseSuperFormulaData(formM: 6, formN1: 0.3, formN2: 0.3, formN3: 0.3)
        ),
        SuperFormulaPreset(
            id: "flower",
            name: "Flower",
            formula1: TkNoiseSuperFormulaData(formM: 8, formN1: 1, formN2: 1, formN3: 8),
            formula2: TkNoiseSuperFormulaData(formM: 1, formN1: 1, formN2: 1, formN3: 1)
        ),
        SuperFormulaPreset(
            id: "asteroid",
            name: "Asteroid",
            formula1: TkNoiseSuperFormulaData(formM: 3, formN1: 4, formN2: 4, formN3: 4),
            formula2: TkNoiseSuperFormulaData(formM: 2, formN1: 5, formN2: 5, formN3: 5)
        )
    ]
}