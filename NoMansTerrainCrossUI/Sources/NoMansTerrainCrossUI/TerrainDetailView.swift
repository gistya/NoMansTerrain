import Foundation
import NoMansTerrainCore
import SwiftCrossUI

/// Editor for one saved terrain — full section parity with the macOS app: General, Noise,
/// Grid, Features, Caves (all per-field Min/Max controls) plus the Region Mixer. SwiftCrossUI
/// has no drag gesture, so region layout is slider-based. Edits flow back through the
/// `terrain` binding, which the app persists on write.
/// Reference channel so the terrain editor's in-progress draft can reach the app (for Save and for
/// switching terrains) WITHOUT writing app-level `@State` on every keystroke — which would recompute
/// the whole window. Writing a class property triggers no view update, so per-edit cost stays local.
final class TerrainEditBuffer {
    var editing: StoredTerrain?
}

struct TerrainDetailView: View {
    /// Source-of-truth terrain from the app; used only to (re)seed `draft` when the selection changes.
    let terrain: StoredTerrain
    /// Where the app reads the in-progress draft on Save / terrain-switch (a reference → no re-render).
    let editBuffer: TerrainEditBuffer
    /// Flags the app dirty on first edit (guarded app-side → ~one app re-render per editing session).
    var onEdited: () -> Void = { }
    /// Commits the current editBuffer draft into the app's array — called just before switching terrains.
    var onCommitDraft: () -> Void = { }
    /// Creates an in-app folder whose 31 slots are all this terrain (the modal's "also save as folder").
    var onCreateTestSetFolder: (StoredTerrain) -> Void = { _ in }
    /// Surfaces export status to the app's status line.
    var onStatus: (String) -> Void = { _ in }

    @Environment(\.chooseFileSaveDestination) private var chooseSaveDestination
    @State private var showTestSetModal = false
    /// The live edit copy. Edits mutate THIS (SwiftCrossUI recomputes only this view's subtree),
    /// not the app's `terrains` array — that's the whole perf fix.
    @State private var draft: StoredTerrain

    init(
        terrain: StoredTerrain,
        editBuffer: TerrainEditBuffer,
        onEdited: @escaping () -> Void = { },
        onCommitDraft: @escaping () -> Void = { },
        onCreateTestSetFolder: @escaping (StoredTerrain) -> Void = { _ in },
        onStatus: @escaping (String) -> Void = { _ in }
    ) {
        self.terrain = terrain
        self.editBuffer = editBuffer
        self.onEdited = onEdited
        self.onCommitDraft = onCommitDraft
        self.onCreateTestSetFolder = onCreateTestSetFolder
        self.onStatus = onStatus
        _draft = State(wrappedValue: terrain)
    }

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

    /// The single write path: update the local draft (scoped re-render), mirror it into the app's
    /// read channel (a reference write → no re-render), and mark the app dirty.
    private func setDraft(_ newValue: StoredTerrain) {
        draft = newValue
        editBuffer.editing = newValue
        onEdited()
    }
    private var draftBinding: Binding<StoredTerrain> {
        Binding(get: { draft }, set: { setDraft($0) })
    }
    private var minData: Binding<TkVoxelGeneratorData> { bind(draftBinding, \.min) }
    private var maxData: Binding<TkVoxelGeneratorData> { bind(draftBinding, \.max) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField("Name", text: bind(draftBinding, \.name))
                // Export this one terrain into all 31 template slots — used for testing, since a
                // planet's terrain template is picked pseudorandomly from its seed, so filling
                // every slot with the same terrain guarantees it shows up regardless.
                Button("⬆ Export as Test Set") { showTestSetModal = true }
            }

            HStack(spacing: 4) {
                ForEach(Section.allCases, id: \.id) { s in
                    Button(s.rawValue) { section = s; layerIndex = 0 }.disabled(section == s)
                }
            }

            layerPicker

            // Randomize just the current section (the Region mixer has its own Smart Mix instead).
            if section != .regions {
                Button("🎲 Randomize \(section.rawValue)") { randomizeSection() }
            }

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
        // The modal: export the .MXML, with the option to also drop a folder into the sidebar.
        .alert("Export test set — all 31 slots use this terrain", isPresented: $showTestSetModal) {
            Button("Export .MXML") { exportTestSet(alsoFolder: false) }
            Button("Export + Save Folder") { exportTestSet(alsoFolder: true) }
            Button("Cancel") { }
        }
        // Selecting a DIFFERENT terrain reuses this view (with its old @State draft) — commit the
        // outgoing draft into the app, then reseed the draft from the newly-selected terrain.
        .onChange(of: terrain.id) {
            onCommitDraft()
            draft = terrain
            editBuffer.editing = nil
        }
    }

    /// Writes a combined `.MXML` with THIS terrain replicated into every one of the 31 game
    /// template slots (so the pseudorandom template pick can't miss it). Optionally also saves an
    /// equivalent folder into the sidebar.
    private func exportTestSet(alsoFolder: Bool) {
        let current = draft   // snapshot the live edit draft so the async write can't race an edit
        if alsoFolder { onCreateTestSetFolder(current) }
        let all = TerrainPreset.all
        let entries = all.map {
            NMSPropertySerializer.CombinedEntry(name: $0.fileBaseName, min: current.min, max: current.max)
        }
        Task {
            guard let chosen = await chooseSaveDestination(
                title: "Export Test Set",
                message: "Writes “\(current.name)” into all \(all.count) template slots.",
                defaultButtonLabel: "Export",
                defaultFileName: "voxelgeneratorsettings.MXML"
            ) else { return } // user cancelled
            // WinUI's save picker hardcodes `.txt`; normalise to the `.MXML` the game expects.
            var url = chosen
            if url.pathExtension.caseInsensitiveCompare("MXML") != .orderedSame {
                url.deletePathExtension()
                url.appendPathExtension("MXML")
                if url != chosen { try? FileManager.default.removeItem(at: chosen) }
            }
            do {
                try NMSPropertySerializer.writeCombined(entries, to: url)
                onStatus("Exported test set — \(entries.count) slots of “\(current.name)” → \(url.path)")
            } catch {
                onStatus("Export failed: \(error)")
            }
        }
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
        let data = showMax ? draft.max : draft.min
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
            get: { (showMax ? draft.max : draft.min)[keyPath: kp] },
            set: { v in
                var d = draft
                if showMax { d.max[keyPath: kp] = v } else { d.min[keyPath: kp] = v }
                setDraft(d)
            }
        )
    }

    private func autoTier() {
        var d = draft
        var data = showMax ? d.max : d.min
        let states = fields.map { RegionLayerRegistry.state($0, in: data) }
        let tiered = RegionFieldSampler.autoTier(states)
        for (field, s) in zip(fields, tiered) where s.active {
            data[keyPath: field.ratio] = s.ratio
            data[keyPath: field.scale] = RegionLayerRegistry.remap(s.scale, from: RegionLayerRegistry.canonicalScaleRange, to: field.scaleRange)
            data[keyPath: field.elevation] = s.elevation
            if let g = field.gain { data[keyPath: g] = s.gain }
        }
        if showMax { d.max = data } else { d.min = data }
        setDraft(d)
    }

    private func smartMix() {
        var d = draft
        var mn = d.min
        var mx = d.max
        var rng = SystemRandomNumberGenerator()
        SmartRegionMix.apply(min: &mn, max: &mx, using: &rng)
        d.min = mn
        d.max = mx
        setDraft(d)
    }

    /// Randomizes every layer/field of the CURRENT section (both Min and Max) within the base
    /// terrain's documented ranges — the per-section equivalent of the macOS randomize buttons.
    private func randomizeSection() {
        let base = BaseTerrain.shared
        var d = draft
        switch section {
        case .general:
            TerrainEditorOperations.randomizeRootScalars(
                minData: &d.min, maxData: &d.max, refMin: base.min, refMax: base.max)
        case .noise:
            for (_, kp) in noiseLayers {
                TerrainEditorOperations.randomizeUberLayer(
                    min: &d.min[keyPath: kp], max: &d.max[keyPath: kp],
                    refMin: base.min[keyPath: kp], refMax: base.max[keyPath: kp])
            }
        case .grid:
            for (_, kp) in gridLayers {
                TerrainEditorOperations.randomizeGrid(
                    min: &d.min[keyPath: kp], max: &d.max[keyPath: kp],
                    refMin: base.min[keyPath: kp], refMax: base.max[keyPath: kp])
            }
        case .features:
            for (_, kp) in featureLayers {
                TerrainEditorOperations.randomizeFeature(
                    min: &d.min[keyPath: kp], max: &d.max[keyPath: kp],
                    refMin: base.min[keyPath: kp], refMax: base.max[keyPath: kp])
            }
        case .caves:
            for (_, kp) in caveLayers {
                TerrainEditorOperations.randomizeFeature(
                    min: &d.min[keyPath: kp], max: &d.max[keyPath: kp],
                    refMin: base.min[keyPath: kp], refMax: base.max[keyPath: kp])
            }
        case .regions:
            break // the Region mixer randomizes via its own Smart Mix
        }
        setDraft(d)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
