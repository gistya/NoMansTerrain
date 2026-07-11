import Foundation
import NoMansTerrainCore
import SwiftCrossUI

/// Editor for one saved terrain — full section parity with the macOS app: General, Noise,
/// Grid, Features, Caves (all per-field Min/Max controls) plus the Region Mixer. SwiftCrossUI
/// has no drag gesture, so region layout is slider-based. Edits flow back through the
/// `terrain` binding, which the app persists on write.
struct TerrainDetailView: View {
    @Binding var terrain: StoredTerrain

    enum Section: String, CaseIterable, Identifiable {
        case general = "General", noise = "Noise", grid = "Grid"
        case features = "Features", caves = "Caves", regions = "Regions"
        var id: String { rawValue }
    }

    @State private var section: Section = .general
    @State private var layerIndex = 0

    // Region-mixer state
    @State private var category: RegionCategory = .noise
    @State private var showMax = false
    @State private var fieldBox = RegionFieldBox()
    private let resolution = 22

    // Per-category layer lists (name + key path into a TkVoxelGeneratorData).
    private let noiseLayers: [(String, WritableKeyPath<TkVoxelGeneratorData, TkNoiseUberLayerData>)] = [
        ("Base", \.noiseLayers.base), ("Hill", \.noiseLayers.hill), ("Mountain", \.noiseLayers.mountain),
        ("Rock", \.noiseLayers.rock), ("Under Water", \.noiseLayers.underWater), ("Texture", \.noiseLayers.texture),
        ("Elevation", \.noiseLayers.elevation), ("Continent", \.noiseLayers.continent)
    ]
    private let gridLayers: [(String, WritableKeyPath<TkVoxelGeneratorData, TkNoiseGridData>)] = [
        ("Small", \.gridLayers.small), ("Large", \.gridLayers.large),
        ("Heridium", \.gridLayers.resourcesHeridium), ("Iridium", \.gridLayers.resourcesIridium),
        ("Copper", \.gridLayers.resourcesCopper), ("Nickel", \.gridLayers.resourcesNickel),
        ("Aluminium", \.gridLayers.resourcesAluminium), ("Gold", \.gridLayers.resourcesGold), ("Emeril", \.gridLayers.resourcesEmeril)
    ]
    private let featureLayers: [(String, WritableKeyPath<TkVoxelGeneratorData, TkNoiseFeatureData>)] = [
        ("River", \.features.river), ("Crater", \.features.crater), ("Arches", \.features.arches),
        ("Arches Small", \.features.archesSmall), ("Blobs", \.features.blobs), ("Blobs Small", \.features.blobsSmall),
        ("Substance", \.features.substance)
    ]
    private let caveLayers: [(String, WritableKeyPath<TkVoxelGeneratorData, TkNoiseFeatureData>)] = [
        ("Cave Mouth", \.caves.underground.mouth), ("Cave Tunnel", \.caves.underground.tunnel)
    ]

    private var minData: Binding<TkVoxelGeneratorData> { bind($terrain, \.min) }
    private var maxData: Binding<TkVoxelGeneratorData> { bind($terrain, \.max) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Name", text: bind($terrain, \.name))

            HStack(spacing: 4) {
                ForEach(Section.allCases, id: \.id) { s in
                    Button(s.rawValue) { section = s; layerIndex = 0 }.disabled(section == s)
                }
            }

            layerPicker

            if section == .regions {
                regionMixer
            } else {
                ScrollView {
                    sectionContent.padding(.trailing, 8)
                }
            }
            Spacer()
        }
        .padding(12)
    }

    // MARK: - Layer sub-picker (Noise/Grid/Features/Caves)

    @ViewBuilder
    private var layerPicker: some View {
        let names: [String] = {
            switch section {
            case .noise: noiseLayers.map(\.0)
            case .grid: gridLayers.map(\.0)
            case .features: featureLayers.map(\.0)
            case .caves: caveLayers.map(\.0)
            default: []
            }
        }()
        if !names.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: 4) {
                    ForEach(Array(names.enumerated()), id: \.offset) { idx, name in
                        Button(name) { layerIndex = idx }.disabled(layerIndex == idx)
                    }
                }
            }
        }
    }

    // MARK: - Section content

    @ViewBuilder
    private var sectionContent: some View {
        switch section {
        case .general:
            GeneralEditor(min: minData, max: maxData, globalMin: BaseTerrain.shared.min, globalMax: BaseTerrain.shared.max)
        case .noise:
            let kp = noiseLayers[safe: layerIndex]?.1 ?? noiseLayers[0].1
            UberLayerEditor(min: bind(minData, kp), max: bind(maxData, kp))
        case .grid:
            let kp = gridLayers[safe: layerIndex]?.1 ?? gridLayers[0].1
            GridLayerEditor(min: bind(minData, kp), max: bind(maxData, kp))
        case .features:
            let kp = featureLayers[safe: layerIndex]?.1 ?? featureLayers[0].1
            FeatureEditor(min: bind(minData, kp), max: bind(maxData, kp))
        case .caves:
            let kp = caveLayers[safe: layerIndex]?.1 ?? caveLayers[0].1
            FeatureEditor(min: bind(minData, kp), max: bind(maxData, kp))
        case .regions:
            EmptyView()
        }
    }

    // MARK: - Region mixer

    private var fields: [RegionLayerField] { RegionLayerRegistry.layers(category) }

    @ViewBuilder
    private var regionMixer: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                ForEach(RegionCategory.allCases, id: \.id) { c in
                    Button(c.title) { category = c }.disabled(category == c)
                }
            }
            HStack(spacing: 6) {
                Button("Min") { showMax = false }.disabled(!showMax)
                Button("Max") { showMax = true }.disabled(showMax)
                Button("Auto-Tier") { autoTier() }
                Button("🎲 Smart Mix") { smartMix() }
            }
            HStack(spacing: 16) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(fields, id: \.id) { field in regionRow(field) }
                    }
                }
                .frame(width: 360)
                VStack(spacing: 6) {
                    Text("Surface preview — which layer wins")
                    RegionHistogramView(box: refreshedBox()).frame(width: 340, height: 340)
                }
            }
        }
    }

    @ViewBuilder
    private func regionRow(_ field: RegionLayerField) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(field.name) — \(pct(field.id))% visible")
            regionSlider("coverage", regionBinding(field.ratio), 0...1)
            regionSlider("patch", regionBinding(field.scale), field.scaleRange)
            regionSlider("height", regionBinding(field.elevation), -128...128)
            if let gain = field.gain { regionSlider("edge", regionBinding(gain), 0...10) }
        }
    }

    private func regionSlider(_ label: String, _ value: Binding<Double>, _ range: ClosedRange<Double>) -> some View {
        HStack(spacing: 6) {
            Text(label).frame(width: 66)
            Slider(value: value, in: range)
        }
    }

    private func refreshedBox() -> RegionFieldBox {
        let data = showMax ? terrain.max : terrain.min
        let states = fields.map { RegionLayerRegistry.state($0, in: data) }
        fieldBox.field = RegionFieldSampler.sample(layers: states, resolution: resolution)
        return fieldBox
    }

    private func pct(_ id: String) -> Int {
        guard let field = fieldBox.field else { return 0 }
        return Int(Double(field.winCounts[id] ?? 0) / Double(resolution * resolution) * 100)
    }

    private func regionBinding(_ kp: WritableKeyPath<TkVoxelGeneratorData, Double>) -> Binding<Double> {
        Binding(
            get: { (showMax ? terrain.max : terrain.min)[keyPath: kp] },
            set: { v in if showMax { terrain.max[keyPath: kp] = v } else { terrain.min[keyPath: kp] = v } }
        )
    }

    private func autoTier() {
        var data = showMax ? terrain.max : terrain.min
        let states = fields.map { RegionLayerRegistry.state($0, in: data) }
        let tiered = RegionFieldSampler.autoTier(states)
        for (field, s) in zip(fields, tiered) where s.active {
            data[keyPath: field.ratio] = s.ratio
            data[keyPath: field.scale] = RegionLayerRegistry.remap(s.scale, from: RegionLayerRegistry.canonicalScaleRange, to: field.scaleRange)
            data[keyPath: field.elevation] = s.elevation
            if let g = field.gain { data[keyPath: g] = s.gain }
        }
        if showMax { terrain.max = data } else { terrain.min = data }
    }

    private func smartMix() {
        var mn = terrain.min
        var mx = terrain.max
        var rng = SystemRandomNumberGenerator()
        SmartRegionMix.apply(min: &mn, max: &mx, using: &rng)
        terrain.min = mn
        terrain.max = mx
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
