import Foundation

/// Pure, UI-free model behind the Region Mask editor: it approximates *where* each layer's
/// procedural region mask fires (from its ratio / scale / gain), so the editor can show a
/// colored 3D histogram of which active layers actually reach the surface vs. which are
/// fully buried. The engine's masks are seed-driven and statistical, so this is an
/// approximation — good enough to author with, not a pixel-exact prediction.

enum RegionMath {
    static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * min(max(t, 0), 1)
    }

    static func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        if edge0 == edge1 { return x < edge0 ? 0 : 1 }
        let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
        return t * t * (3 - 2 * t)
    }
}

/// Deterministic 2D value noise (bilinear, smoothstep-interpolated) used as the stand-in
/// for the engine's region noise.
struct ValueNoise2D {
    let seed: UInt64

    private func hash(_ xi: Int, _ yi: Int) -> Double {
        var h = seed
        h = h &+ UInt64(bitPattern: Int64(xi)) &* 0x9E3779B97F4A7C15
        h = h &+ UInt64(bitPattern: Int64(yi)) &* 0xC2B2AE3D27D4EB4F
        h ^= h >> 29; h = h &* 0xBF58476D1CE4E5B9; h ^= h >> 32
        return Double(h >> 11) * (1.0 / 9007199254740992.0) // [0,1)
    }

    func value(_ x: Double, _ y: Double) -> Double {
        let x0 = Int(floor(x)), y0 = Int(floor(y))
        let fx = x - Double(x0), fy = y - Double(y0)
        let sx = fx * fx * (3 - 2 * fx), sy = fy * fy * (3 - 2 * fy)
        let v00 = hash(x0, y0), v10 = hash(x0 + 1, y0)
        let v01 = hash(x0, y0 + 1), v11 = hash(x0 + 1, y0 + 1)
        let a = v00 + (v10 - v00) * sx
        let b = v01 + (v11 - v01) * sx
        return a + (b - a) * sy
    }
}

/// A single layer's region settings as the editor sees them.
struct RegionLayerState: Identifiable, Sendable, Equatable {
    let id: String
    let name: String
    let colorIndex: Int
    var active: Bool
    var ratio: Double        // coverage 0…1
    var scale: Double        // patch size (RegionScale, ~0.95…19.95)
    var gain: Double         // edge contrast (RegionGain); ignored when !hasGain
    var hasGain: Bool        // grids have no RegionGain
    var elevation: Double    // heightOffset → tier (drives occlusion in the preview)
}

enum RegionMask {
    /// Visual world span sampled by the preview; a handful of patches across the view.
    static let worldSpan = 8.0

    static func frequency(scale: Double) -> Double {
        6.0 / max(scale, 0.5) // bigger scale → bigger patches → lower frequency
    }

    static func edge(gain: Double, hasGain: Bool) -> Double {
        hasGain ? 0.25 / (1 + max(gain, 0)) : 0.09 // higher gain → sharper mask edge
    }

    /// Mask coverage in [0,1] at a normalized world coordinate.
    static func mask(_ layer: RegionLayerState, x: Double, y: Double) -> Double {
        let r = min(max(layer.ratio, 0), 1)
        if r <= 0 { return 0 }
        if r >= 1 { return 1 }
        let noise = ValueNoise2D(seed: stableSeed(layer.id))
        let f = frequency(scale: layer.scale)
        let n = noise.value(x * f, y * f)
        // Value noise is bell-shaped (≈triangular on [0,1]), not uniform, so a plain
        // `1 - ratio` threshold under-covers. Use the triangular inverse-CDF so the covered
        // fraction (mask > 0.5, i.e. noise > t) actually tracks `ratio`.
        let t = r <= 0.5 ? 1 - (r / 2).squareRoot() : ((1 - r) / 2).squareRoot()
        let e = RegionMask.edge(gain: layer.gain, hasGain: layer.hasGain)
        return RegionMath.smoothstep(t - e, t + e, n)
    }
}

struct RegionFieldCell: Sendable {
    /// Index into the *active* layer list that reaches the surface here (nil = bare ground).
    var surface: Int?
    var height: Double      // 0…1 normalized bar height
    var colorIndex: Int     // -1 when bare
}

struct RegionField: Sendable {
    let resolution: Int
    var cells: [RegionFieldCell]
    /// Layer id → number of cells where it is the surface (its visibility).
    var winCounts: [String: Int]

    func cell(_ i: Int, _ j: Int) -> RegionFieldCell { cells[j * resolution + i] }
}

enum RegionFieldSampler {
    /// Samples the combined region field. At each cell the *highest-elevation* active layer
    /// whose mask is present wins the surface (so a broad high layer visibly buries lower
    /// ones — which is exactly what Auto-Tier fixes).
    static func sample(layers: [RegionLayerState], resolution: Int) -> RegionField {
        let active = layers.filter { $0.active }
        let elevs = active.map(\.elevation)
        let minE = elevs.min() ?? 0, maxE = elevs.max() ?? 1
        func norm(_ e: Double) -> Double { maxE > minE ? (e - minE) / (maxE - minE) : 0.5 }

        var cells: [RegionFieldCell] = []
        cells.reserveCapacity(resolution * resolution)
        var wins: [String: Int] = [:]

        for j in 0..<resolution {
            for i in 0..<resolution {
                let x = Double(i) / Double(resolution) * RegionMask.worldSpan
                let y = Double(j) / Double(resolution) * RegionMask.worldSpan
                var bestIdx: Int?
                var bestElev = -Double.greatestFiniteMagnitude
                for (k, layer) in active.enumerated() {
                    if RegionMask.mask(layer, x: x, y: y) > 0.5, layer.elevation > bestElev {
                        bestElev = layer.elevation
                        bestIdx = k
                    }
                }
                if let bi = bestIdx {
                    let layer = active[bi]
                    cells.append(RegionFieldCell(surface: bi,
                                                 height: 0.15 + 0.85 * norm(layer.elevation),
                                                 colorIndex: layer.colorIndex))
                    wins[layer.id, default: 0] += 1
                } else {
                    cells.append(RegionFieldCell(surface: nil, height: 0.06, colorIndex: -1))
                }
            }
        }
        return RegionField(resolution: resolution, cells: cells, winCounts: wins)
    }

    /// Spreads the active layers across distinct coverage / patch-size / elevation tiers so
    /// each is statistically likely to win some surface cells (i.e. be visible). Lower tiers
    /// get broad coverage; higher tiers get rare peaks that poke through.
    static func autoTier(_ layers: [RegionLayerState]) -> [RegionLayerState] {
        var result = layers
        let activeIdx = layers.indices.filter { layers[$0].active }
        let n = activeIdx.count
        guard n > 0 else { return layers }

        for (rank, idx) in activeIdx.enumerated() {
            let t = n == 1 ? 0.0 : Double(rank) / Double(n - 1) // 0 = lowest tier
            result[idx].ratio = RegionMath.lerp(0.6, 0.18, t)   // broad base → rare peaks
            result[idx].scale = RegionMath.lerp(3.0, 12.0, Double(rank % 4) / 3.0) // varied patch sizes
            result[idx].elevation = RegionMath.lerp(-40, 90, t) // distinct height bands
            if result[idx].hasGain { result[idx].gain = RegionMath.lerp(1.5, 4.0, t) }
        }
        return result
    }
}
