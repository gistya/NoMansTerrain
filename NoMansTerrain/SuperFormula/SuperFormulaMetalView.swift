import NoMansTerrainCore
import MetalKit
import SwiftUI

#if os(macOS)
import AppKit

struct SuperFormulaMetalView: NSViewRepresentable {
    @Bindable var state: SuperFormulaEditorState

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView()
        configure(view: view, context: context)
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        context.coordinator.sync(state: state, view: nsView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
}
#else
import UIKit

struct SuperFormulaMetalView: UIViewRepresentable {
    @Bindable var state: SuperFormulaEditorState

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        configure(view: view, context: context)
        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.sync(state: state, view: uiView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
}
#endif

extension SuperFormulaMetalView {
    @MainActor
    final class Coordinator: NSObject {
        let renderer = SuperFormulaMetalRenderer()
        private var lastMeshSignature = ""

        func sync(state: SuperFormulaEditorState, view: MTKView) {
            renderer.cameraAzimuth = state.cameraAzimuth
            renderer.cameraElevation = state.cameraElevation
            renderer.cameraDistance = state.cameraDistance

            let signature = state.meshSignature
            if signature != lastMeshSignature {
                lastMeshSignature = signature
                renderer.updateMesh(state.mesh)
            }

            view.setNeedsDisplay(view.bounds)
        }
    }

    private func configure(view: MTKView, context: Context) {
        guard let device = MTLCreateSystemDefaultDevice() else { return }
        view.device = device
        view.delegate = context.coordinator.renderer
        view.colorPixelFormat = .bgra8Unorm
        view.depthStencilPixelFormat = .depth32Float
        view.clearColor = MTLClearColor(red: 0.04, green: 0.05, blue: 0.08, alpha: 1)
        view.enableSetNeedsDisplay = true
        view.isPaused = true
        view.preferredFramesPerSecond = 60
        context.coordinator.sync(state: state, view: view)
    }
}
