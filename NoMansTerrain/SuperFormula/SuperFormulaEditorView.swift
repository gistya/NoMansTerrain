import SwiftUI

struct SuperFormulaEditorView: View {
    @State private var state = SuperFormulaEditorState()
    @State private var copiedConfirmation = false
    @State private var orbitBaseAzimuth: Float = 0.6
    @State private var orbitBaseElevation: Float = 0.35
    @State private var zoomBaseDistance: Float = 3.2

    var body: some View {
        @Bindable var state = state

        NavigationSplitView {
            controlPanel(state: state)
                .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 380)
        } detail: {
            previewPanel
        }
        .navigationTitle("SuperFormula Playground")
    }

    private var previewPanel: some View {
        ZStack(alignment: .topTrailing) {
            SuperFormulaMetalView(state: state)
                .gesture(cameraDragGesture)
                .gesture(cameraZoomGesture)

            VStack(alignment: .trailing) {
                Text("Drag to orbit · Pinch/scroll to zoom")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))

                if copiedConfirmation {
                    Label("Copied XML", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .padding(8)
                        .background(.green.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding()
            .animation(.snappy, value: copiedConfirmation)
        }
    }

    private func controlPanel(state: SuperFormulaEditorState) -> some View {
        @Bindable var state = state

        return Form {
            Section("Presets") {
                Picker("Preset", selection: Binding(
                    get: { "" },
                    set: { presetID in
                        guard let preset = SuperFormulaPreset.defaults.first(where: { $0.id == presetID }) else { return }
                        state.applyPreset(preset)
                    }
                )) {
                    Text("Choose preset…").tag("")
                    ForEach(SuperFormulaPreset.defaults) { preset in
                        Text(preset.name).tag(preset.id)
                    }
                }
            }

            formulaSection(title: "SuperFormula 1", formula: state.formula1Binding, mRange: 0.1...10, n1Range: 0...100)
            formulaSection(title: "SuperFormula 2", formula: state.formula2Binding, mRange: 0.1...10, n1Range: 0...100)

            Section("SuperPrimitive") {
                let primitive = state.primitiveBinding
                primitiveSlider("Width", value: primitive.nested(\.width), range: 0.1...1)
                primitiveSlider("Height", value: primitive.nested(\.height), range: 0.1...1)
                primitiveSlider("Depth", value: primitive.nested(\.depth), range: 0.1...1)
                primitiveSlider("Thickness", value: primitive.nested(\.thickness), range: 0.1...1)
                primitiveSlider("Corner Radius XY", value: primitive.nested(\.cornerRadiusXY), range: 0...1)
                primitiveSlider("Corner Radius Z", value: primitive.nested(\.cornerRadiusZ), range: 0...1)
                primitiveSlider("Bottom Radius Offset", value: primitive.nested(\.bottomRadiusOffset), range: 0...1)
            }

            Section("NMS XML") {
                Text(state.xmlSnippet)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .lineLimit(nil)

                Button("Copy XML to Clipboard", systemImage: "doc.on.doc") {
                    copyXML()
                }
            }
        }
        .formStyle(.grouped)
        .terrainScrollEdgeEffect()
    }

    private func formulaSection(
        title: String,
        formula: Binding<TkNoiseSuperFormulaData>,
        mRange: ClosedRange<Double>,
        n1Range: ClosedRange<Double>
    ) -> some View {
        Section(title) {
            formulaSlider("Form_m", value: formula.nested(\.formM), range: mRange)
            formulaSlider("Form_n1", value: formula.nested(\.formN1), range: n1Range)
            formulaSlider("Form_n2", value: formula.nested(\.formN2), range: -50...100)
            formulaSlider("Form_n3", value: formula.nested(\.formN3), range: -50...100)
        }
    }

    private func formulaSlider(_ label: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading) {
            LabeledContent(label) {
                Text(value.wrappedValue, format: .number.precision(.fractionLength(3)))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
        }
    }

    private func primitiveSlider(_ label: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        formulaSlider(label, value: value, range: range)
    }

    private var cameraDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                state.cameraAzimuth = orbitBaseAzimuth + Float(value.translation.width) * 0.005
                state.cameraElevation = clamp(
                    orbitBaseElevation - Float(value.translation.height) * 0.005,
                    min: -1.2,
                    max: 1.2
                )
            }
            .onEnded { _ in
                orbitBaseAzimuth = state.cameraAzimuth
                orbitBaseElevation = state.cameraElevation
            }
    }

    private var cameraZoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                state.cameraDistance = clamp(zoomBaseDistance / Float(value.magnification), min: 1.4, max: 8)
            }
            .onEnded { value in
                zoomBaseDistance = clamp(zoomBaseDistance / Float(value.magnification), min: 1.4, max: 8)
                state.cameraDistance = zoomBaseDistance
            }
    }

    private func copyXML() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(state.xmlSnippet, forType: .string)
        #else
        UIPasteboard.general.string = state.xmlSnippet
        #endif

        withAnimation(.snappy) {
            copiedConfirmation = true
        }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(.snappy) {
                copiedConfirmation = false
            }
        }
    }

    private func clamp(_ value: Float, min: Float, max: Float) -> Float {
        Swift.min(Swift.max(value, min), max)
    }
}

#if os(macOS)
import AppKit
#else
import UIKit
#endif

#Preview {
    SuperFormulaEditorView()
}