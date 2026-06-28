import SwiftUI

/// Color-codes layers in both the squares and the 3D histogram.
enum RegionPalette {
    static let colors: [Color] = [
        .red, .orange, .yellow, .green, .mint, .teal, .cyan, .blue,
        .indigo, .purple, .pink, .brown, Color(red: 0.6, green: 0.8, blue: 0.2),
        Color(red: 0.9, green: 0.5, blue: 0.7), Color(red: 0.3, green: 0.7, blue: 0.9),
        Color(red: 0.8, green: 0.4, blue: 0.2), Color(red: 0.5, green: 0.9, blue: 0.6)
    ]
    static func color(_ index: Int) -> Color {
        index < 0 ? Color.gray.opacity(0.5) : colors[index % colors.count]
    }
}

/// One layer's editable region fields, addressed by key path into a `TkVoxelGeneratorData`.
struct RegionLayerDesc: Identifiable {
    let id: String
    let name: String
    let colorIndex: Int
    let active: WritableKeyPath<TkVoxelGeneratorData, Bool>
    let ratio: WritableKeyPath<TkVoxelGeneratorData, Double>
    let scale: WritableKeyPath<TkVoxelGeneratorData, Double>
    let gain: WritableKeyPath<TkVoxelGeneratorData, Double>?   // nil for grids
    let elevation: WritableKeyPath<TkVoxelGeneratorData, Double>
}

/// Region-mask authoring surface: a square per noise/grid layer (drag to set patch size &
/// coverage), a live colored 3D histogram showing which active layers reach the surface,
/// and an Auto-Tier button that spreads the active layers so they're all likely visible.
struct RegionMaskEditorView: View {
    @Bindable var session: TerrainEditorSession

    enum Sub: String, CaseIterable, Identifiable {
        case noise = "Noise Layers", grid = "Grid Layers"
        var id: String { rawValue }
    }
    @State private var sub: Sub = .noise
    @State private var showMax = false

    private let resolution = 18

    private var descriptors: [RegionLayerDesc] {
        sub == .noise ? Self.noiseDescriptors : Self.gridDescriptors
    }

    private var data: TkVoxelGeneratorData { showMax ? session.maxData : session.minData }

    private var states: [RegionLayerState] {
        descriptors.map { d in
            RegionLayerState(
                id: d.id, name: d.name, colorIndex: d.colorIndex,
                active: data[keyPath: d.active],
                ratio: data[keyPath: d.ratio],
                scale: data[keyPath: d.scale],
                gain: d.gain.map { data[keyPath: $0] } ?? 2,
                hasGain: d.gain != nil,
                elevation: data[keyPath: d.elevation]
            )
        }
    }

    private var field: RegionField {
        RegionFieldSampler.sample(layers: states, resolution: resolution)
    }

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        VStack(spacing: 10) {
            controls
            RegionHistogramView(field: field)
                .frame(height: 360)
                .frame(maxWidth: 880)
                .background(Color.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
                .frame(maxWidth: .infinity) // center the box within the full width
                .padding(.horizontal)
            legend
            Divider()
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(descriptors) { desc in
                        RegionSquareEditor(
                            name: desc.name,
                            color: RegionPalette.color(desc.colorIndex),
                            active: bindBool(desc.active),
                            ratio: bindDouble(desc.ratio),
                            scale: bindDouble(desc.scale),
                            elevation: bindDouble(desc.elevation),
                            gain: desc.gain.map { bindDouble($0) }
                        )
                    }
                }
                .padding()
            }
        }
    }

    private var controls: some View {
        HStack {
            Picker("", selection: $sub) {
                ForEach(Sub.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 280)

            Spacer()

            Picker("", selection: $showMax) {
                Text("Min").tag(false)
                Text("Max").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 120)

            Button {
                autoTier()
            } label: {
                Label("Auto-Tier", systemImage: "square.3.layers.3d")
            }
            .help("Spread the active \(sub == .noise ? "noise" : "grid") layers across distinct coverage, patch-size and elevation tiers so each is likely to be visible.")
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var legend: some View {
        let total = resolution * resolution
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(states.filter(\.active)) { state in
                    let won = field.winCounts[state.id] ?? 0
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(RegionPalette.color(state.colorIndex))
                            .frame(width: 12, height: 12)
                        Text(state.name).font(.caption)
                        Text(won == 0 ? "hidden" : "\(Int((Double(won) / Double(total)) * 100))%")
                            .font(.caption2)
                            .foregroundStyle(won == 0 ? Color.orange : .secondary)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Bindings & actions

    /// Two-way binding for a numeric region field that keeps the Min/Max pair valid: a Min
    /// value never rises above its Max, and a Max value never drops below its Min (the
    /// edit nudges the other set rather than allowing an inverted range).
    private func bindDouble(_ kp: WritableKeyPath<TkVoxelGeneratorData, Double>) -> Binding<Double> {
        Binding(
            get: { (showMax ? session.maxData : session.minData)[keyPath: kp] },
            set: { newValue in
                if showMax {
                    var mx = session.maxData; mx[keyPath: kp] = newValue
                    session.maxDataBinding.wrappedValue = mx
                    if session.minData[keyPath: kp] > newValue { // pull min down to stay ≤ max
                        var mn = session.minData; mn[keyPath: kp] = newValue
                        session.minDataBinding.wrappedValue = mn
                    }
                } else {
                    var mn = session.minData; mn[keyPath: kp] = newValue
                    session.minDataBinding.wrappedValue = mn
                    if session.maxData[keyPath: kp] < newValue { // push max up to stay ≥ min
                        var mx = session.maxData; mx[keyPath: kp] = newValue
                        session.maxDataBinding.wrappedValue = mx
                    }
                }
            }
        )
    }

    private func bindBool(_ kp: WritableKeyPath<TkVoxelGeneratorData, Bool>) -> Binding<Bool> {
        let base = showMax ? session.maxDataBinding : session.minDataBinding
        return Binding(
            get: { base.wrappedValue[keyPath: kp] },
            set: { var d = base.wrappedValue; d[keyPath: kp] = $0; base.wrappedValue = d }
        )
    }

    private func autoTier() {
        let base = showMax ? session.maxDataBinding : session.minDataBinding
        var d = base.wrappedValue
        let tiered = RegionFieldSampler.autoTier(states)
        for (desc, s) in zip(descriptors, tiered) where s.active {
            d[keyPath: desc.ratio] = s.ratio
            d[keyPath: desc.scale] = s.scale
            d[keyPath: desc.elevation] = s.elevation
            if let g = desc.gain { d[keyPath: g] = s.gain }
        }
        base.wrappedValue = d
        normalizeRegionRanges()
    }

    /// Orders every region field so Min ≤ Max (Auto-Tier only rewrites one set, so the other
    /// can end up inverted). Preserves both values — it just sorts them into the right set.
    private func normalizeRegionRanges() {
        var mn = session.minData
        var mx = session.maxData
        var changed = false
        for desc in descriptors {
            var kps = [desc.ratio, desc.scale, desc.elevation]
            if let g = desc.gain { kps.append(g) }
            for kp in kps {
                let lo = Swift.min(mn[keyPath: kp], mx[keyPath: kp])
                let hi = Swift.max(mn[keyPath: kp], mx[keyPath: kp])
                if mn[keyPath: kp] != lo { mn[keyPath: kp] = lo; changed = true }
                if mx[keyPath: kp] != hi { mx[keyPath: kp] = hi; changed = true }
            }
        }
        if changed {
            session.minDataBinding.wrappedValue = mn
            session.maxDataBinding.wrappedValue = mx
        }
    }
}

// MARK: - Layer registries

extension RegionMaskEditorView {
    static let noiseDescriptors: [RegionLayerDesc] = {
        let layers: [(String, WritableKeyPath<NoiseLayers, TkNoiseUberLayerData>)] = [
            ("Base", \.base), ("Hill", \.hill), ("Mountain", \.mountain), ("Rock", \.rock),
            ("Under Water", \.underWater), ("Texture", \.texture), ("Elevation", \.elevation), ("Continent", \.continent)
        ]
        return layers.enumerated().map { index, entry in
            let (name, lp) = entry
            func kp<V>(_ leaf: WritableKeyPath<TkNoiseUberLayerData, V>) -> WritableKeyPath<TkVoxelGeneratorData, V> {
                let root: WritableKeyPath<TkVoxelGeneratorData, NoiseLayers> = \.noiseLayers
                let mid: WritableKeyPath<NoiseLayers, V> = lp.appending(path: leaf)
                return root.appending(path: mid)
            }
            return RegionLayerDesc(
                id: "noise.\(name)", name: name, colorIndex: index,
                active: kp(\.active),
                ratio: kp(\.regionRatio),
                scale: kp(\.regionScale),
                gain: kp(\.regionGain),
                elevation: kp(\.heightOffset)
            )
        }
    }()

    static let gridDescriptors: [RegionLayerDesc] = {
        let layers: [(String, WritableKeyPath<GridLayers, TkNoiseGridData>)] = [
            ("Small", \.small), ("Large", \.large),
            ("Heridium", \.resourcesHeridium), ("Iridium", \.resourcesIridium),
            ("Copper", \.resourcesCopper), ("Nickel", \.resourcesNickel),
            ("Aluminium", \.resourcesAluminium), ("Gold", \.resourcesGold), ("Emeril", \.resourcesEmeril)
        ]
        return layers.enumerated().map { index, entry in
            let (name, lp) = entry
            func kp<V>(_ leaf: WritableKeyPath<TkNoiseGridData, V>) -> WritableKeyPath<TkVoxelGeneratorData, V> {
                let root: WritableKeyPath<TkVoxelGeneratorData, GridLayers> = \.gridLayers
                let mid: WritableKeyPath<GridLayers, V> = lp.appending(path: leaf)
                return root.appending(path: mid)
            }
            return RegionLayerDesc(
                id: "grid.\(name)", name: name, colorIndex: index,
                active: kp(\.active),
                ratio: kp(\.regionRatio),
                scale: kp(\.regionScale),
                gain: nil, // grids have no RegionGain
                elevation: kp(\.heightOffset)
            )
        }
    }()
}

// MARK: - Draggable region square

/// A single layer's region control: a square on a gridded backdrop whose **width = patch
/// size (RegionScale)** and **height = coverage (RegionRatio)**, dragged from the corner.
/// Edge softness visualizes RegionGain (noise layers only), also adjustable below.
struct RegionSquareEditor: View {
    let name: String
    let color: Color
    @Binding var active: Bool
    @Binding var ratio: Double
    @Binding var scale: Double
    @Binding var elevation: Double
    var gain: Binding<Double>?

    private let box: CGFloat = 132
    private let pad: CGFloat = 8
    private let minSide: CGFloat = 16

    private let scaleRange = 0.95...19.95

    private var span: CGFloat { (box - 2 * pad) - minSide }

    private var rectWidth: CGFloat {
        let frac = (scale - scaleRange.lowerBound) / (scaleRange.upperBound - scaleRange.lowerBound)
        return minSide + CGFloat(min(max(frac, 0), 1)) * span
    }
    private var rectHeight: CGFloat {
        minSide + CGFloat(min(max(ratio, 0), 1)) * span
    }
    private var blurRadius: CGFloat {
        guard let gain else { return 1.5 }
        return 6 * (1 - CGFloat(min(max(gain.wrappedValue, 0), 10) / 10)) // high gain → hard edge
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: $active) {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 12, height: 12)
                    Text(name).font(.subheadline.weight(.medium)).lineLimit(1)
                }
            }
            .toggleStyle(.button)
            .buttonStyle(.borderless)

            ZStack(alignment: .topLeading) {
                gridBackdrop
                RoundedRectangle(cornerRadius: 5)
                    .fill(color.opacity(active ? 0.7 : 0.3))
                    .frame(width: rectWidth, height: rectHeight)
                    .blur(radius: blurRadius)
                    .offset(x: pad, y: pad)
                Circle()
                    .fill(.white)
                    .overlay(Circle().stroke(color, lineWidth: 2))
                    .frame(width: 16, height: 16)
                    .offset(x: pad + rectWidth - 8, y: pad + rectHeight - 8)
            }
            .frame(width: box, height: box)
            .coordinateSpace(name: "box")
            .contentShape(Rectangle())
            .gesture(cornerDrag)
            .opacity(active ? 1 : 0.55)

            Text("Patch \(scale, format: .number.precision(.fractionLength(1))) · Cover \(Int(ratio * 100))%")
                .font(.caption2).foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Height Offset \(Int(elevation))")
                    .font(.caption2).foregroundStyle(.secondary)
                Slider(value: $elevation, in: -128...128)
            }

            if let gain {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Edge \(gain.wrappedValue, format: .number.precision(.fractionLength(1)))")
                        .font(.caption2).foregroundStyle(.secondary)
                    Slider(value: gain, in: 0...10)
                }
            }
        }
    }

    private var gridBackdrop: some View {
        Canvas { ctx, size in
            let step = (size.width - 2 * pad) / 6
            var path = Path()
            for k in 0...6 {
                let v = pad + CGFloat(k) * step
                path.move(to: CGPoint(x: v, y: pad)); path.addLine(to: CGPoint(x: v, y: size.height - pad))
                path.move(to: CGPoint(x: pad, y: v)); path.addLine(to: CGPoint(x: size.width - pad, y: v))
            }
            ctx.stroke(path, with: .color(.gray.opacity(0.25)), lineWidth: 0.5)
        }
        .frame(width: box, height: box)
        .background(Color.gray.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
    }

    private var cornerDrag: some Gesture {
        DragGesture(coordinateSpace: .named("box"))
            .onChanged { value in
                let lx = min(max(value.location.x - pad, minSide), box - 2 * pad)
                let ly = min(max(value.location.y - pad, minSide), box - 2 * pad)
                let fracX = Double((lx - minSide) / span)
                let fracY = Double((ly - minSide) / span)
                scale = scaleRange.lowerBound + fracX * (scaleRange.upperBound - scaleRange.lowerBound)
                ratio = min(max(fracY, 0), 1)
            }
    }
}

// MARK: - Isometric 3D histogram

/// Renders the sampled region field as a colored isometric 3D bar chart. Each surface cell
/// is a bar at its layer's elevation, colored by layer; bare cells are low and gray. Where
/// a layer's color never appears, that layer is buried (Auto-Tier fixes that).
struct RegionHistogramView: View {
    let field: RegionField

    var body: some View {
        Canvas { ctx, size in draw(ctx, size: size) }
    }

    private func draw(_ ctx: GraphicsContext, size: CGSize) {
        let res = field.resolution
        guard res > 1 else { return }

        // Fit the whole isometric footprint (base diamond + bar headroom) inside the canvas
        // regardless of aspect ratio, then center it — otherwise a wide/short box crops it.
        let n = Double(res - 1)
        let footprintW = n                 // total width  = n · u
        let footprintH = n * 0.5 + 2.0     // base height (n · 0.5 · u) + 2u of bar headroom
        let u = min(size.width / footprintW, size.height / footprintH) * 0.9
        let tileW = u
        let tileH = u * 0.5
        let heightScale = u * 2.0
        let totalH = n * 0.5 * u + heightScale
        let originX = size.width / 2
        let originY = (size.height - totalH) / 2 + heightScale

        func project(_ i: Double, _ j: Double, _ h: Double) -> CGPoint {
            CGPoint(
                x: originX + (i - j) * tileW / 2,
                y: originY + (i + j) * tileH / 2 - h * heightScale
            )
        }

        // Painter's order: back (small i+j) first.
        var order: [(Int, Int)] = []
        order.reserveCapacity(res * res)
        for j in 0..<res { for i in 0..<res { order.append((i, j)) } }
        order.sort { ($0.0 + $0.1) < ($1.0 + $1.1) }

        for (i, j) in order {
            let cell = field.cell(i, j)
            let h = cell.height
            let base = RegionPalette.color(cell.colorIndex)
            let di = Double(i), dj = Double(j)

            // Right (east) face.
            var right = Path()
            right.move(to: project(di + 1, dj, h))
            right.addLine(to: project(di + 1, dj + 1, h))
            right.addLine(to: project(di + 1, dj + 1, 0))
            right.addLine(to: project(di + 1, dj, 0))
            right.closeSubpath()
            ctx.fill(right, with: .color(base))
            ctx.fill(right, with: .color(.black.opacity(0.28)))

            // Left (south) face.
            var left = Path()
            left.move(to: project(di, dj + 1, h))
            left.addLine(to: project(di + 1, dj + 1, h))
            left.addLine(to: project(di + 1, dj + 1, 0))
            left.addLine(to: project(di, dj + 1, 0))
            left.closeSubpath()
            ctx.fill(left, with: .color(base))
            ctx.fill(left, with: .color(.black.opacity(0.45)))

            // Top face.
            var top = Path()
            top.move(to: project(di, dj, h))
            top.addLine(to: project(di + 1, dj, h))
            top.addLine(to: project(di + 1, dj + 1, h))
            top.addLine(to: project(di, dj + 1, h))
            top.closeSubpath()
            ctx.fill(top, with: .color(base))
        }
    }
}
