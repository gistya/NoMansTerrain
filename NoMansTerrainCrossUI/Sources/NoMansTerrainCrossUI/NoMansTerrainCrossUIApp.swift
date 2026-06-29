import DefaultBackend
import NoMansTerrainCore
import SwiftCrossUI

/// Cross-platform spike mirroring the macOS app's "Regions" tab, in pure Swift via
/// SwiftCrossUI on top of the shared `NoMansTerrainCore`:
///  - Noise (8) / Grid (9) layer sections + Min / Max sets.
///  - Per-layer sliders (SwiftCrossUI has no drag gesture → sliders, like the plan).
///  - Auto-Tier button (shared `RegionFieldSampler.autoTier`).
///  - Isometric 3D histogram rendered to an RGBA buffer in the core and shown as an `Image`
///    (bridges SwiftCrossUI's lack of a `Canvas`).
@main
struct NoMansTerrainCrossUIApp: App {
    enum Section { case noise, grid }

    @State var section: Section = .noise
    @State var showMax = false

    @State var noiseMin = makeNoiseLayers()
    @State var noiseMax = makeNoiseLayers()
    @State var gridMin = makeGridLayers()
    @State var gridMax = makeGridLayers()

    /// Shared holder feeding the (frozen) histogram representable — see RegionHistogramView.
    @State private var fieldBox = RegionFieldBox()

    private let resolution = 24

    private var activeLayers: [RegionLayerState] {
        switch (section, showMax) {
        case (.noise, false): noiseMin
        case (.noise, true): noiseMax
        case (.grid, false): gridMin
        case (.grid, true): gridMax
        }
    }

    private func mutateActive(_ body: (inout [RegionLayerState]) -> Void) {
        switch (section, showMax) {
        case (.noise, false): body(&noiseMin)
        case (.noise, true): body(&noiseMax)
        case (.grid, false): body(&gridMin)
        case (.grid, true): body(&gridMax)
        }
    }

    private func bind<V>(_ i: Int, _ keyPath: WritableKeyPath<RegionLayerState, V>) -> Binding<V> {
        Binding(
            get: { activeLayers[i][keyPath: keyPath] },
            set: { newValue in mutateActive { $0[i][keyPath: keyPath] = newValue } }
        )
    }

    /// Samples the field once per render and stashes it in the shared box, so the histogram
    /// representable (whose stored props SwiftCrossUI freezes at init) reads the current
    /// value in `updateNSView`.
    private func currentField() -> RegionField {
        let f = RegionFieldSampler.sample(layers: activeLayers, resolution: resolution)
        fieldBox.field = f
        return f
    }

    var body: some Scene {
        WindowGroup("NoMansTerrain — Region Mixer (Cross-Platform Spike)") {
            // Sample the field ONCE per render and thread it through — it was previously a
            // computed property re-sampled ~19×/frame (histogram + every legend/row pct()).
            let field = currentField()
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    toggles
                    Button("Auto-Tier") { mutateActive { $0 = RegionFieldSampler.autoTier($0) } }
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(0..<activeLayers.count), id: \.self) { i in
                                layerRow(i, field: field)
                            }
                        }
                    }
                }
                .frame(width: 340)

                VStack(spacing: 10) {
                    Text("Surface preview — which layer wins (3D, native)")
                    RegionHistogramView(box: fieldBox).frame(width: 360, height: 360)
                    legend(field: field)
                }
            }
            .padding(20)
        }
    }

    private var toggles: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Button("Noise Layers") { section = .noise }.disabled(section == .noise)
                Button("Grid Layers") { section = .grid }.disabled(section == .grid)
            }
            HStack(spacing: 8) {
                Button("Min") { showMax = false }.disabled(!showMax)
                Button("Max") { showMax = true }.disabled(showMax)
            }
        }
    }

    @ViewBuilder
    private func layerRow(_ i: Int, field: RegionField) -> some View {
        let layer = activeLayers[i]
        VStack(alignment: .leading, spacing: 2) {
            Text("\(layer.name) — \(pct(layer.id, field: field))% visible")
            slider("coverage", bind(i, \.ratio), 0...1)
            slider("patch", bind(i, \.scale), 0.95...19.95)
            slider("height", bind(i, \.elevation), -128...128)
            if layer.hasGain {
                slider("edge", bind(i, \.gain), 0...10)
            }
        }
    }

    private func slider(_ label: String, _ value: Binding<Double>, _ range: ClosedRange<Double>) -> some View {
        HStack(spacing: 6) {
            Text(label).frame(width: 70)
            Slider(value: value, in: range)
        }
    }

    private func legend(field: RegionField) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(activeLayers, id: \.id) { layer in
                Text("\(layer.name): \(pct(layer.id, field: field))%")
            }
        }
    }

    private func pct(_ id: String, field: RegionField) -> Int {
        let total = resolution * resolution
        return Int(Double(field.winCounts[id] ?? 0) / Double(total) * 100)
    }
}

// MARK: - Initial layer sets (auto-tiered so the defaults look varied)

private func makeNoiseLayers() -> [RegionLayerState] {
    let names = ["Base", "Hill", "Mountain", "Rock", "Under Water", "Texture", "Elevation", "Continent"]
    let layers = names.enumerated().map { index, name in
        RegionLayerState(id: "noise.\(name)", name: name, colorIndex: index, active: true,
                         ratio: 0.5, scale: 6, gain: 2, hasGain: true, elevation: 0)
    }
    return RegionFieldSampler.autoTier(layers)
}

private func makeGridLayers() -> [RegionLayerState] {
    let names = ["Small", "Large", "Heridium", "Iridium", "Copper", "Nickel", "Aluminium", "Gold", "Emeril"]
    let layers = names.enumerated().map { index, name in
        RegionLayerState(id: "grid.\(name)", name: name, colorIndex: index, active: true,
                         ratio: 0.4, scale: 6, gain: 2, hasGain: false, elevation: 0)
    }
    return RegionFieldSampler.autoTier(layers)
}
