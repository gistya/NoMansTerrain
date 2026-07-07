import Foundation

/// "Randomized smart region mixing": arranges the region-mixing fields of *every* layer the
/// Region Mixer controls (all noise, grid, feature and cave layers) into a balanced,
/// randomized spread so each layer wins some surface — a good smattering of everything with
/// **nothing pinned to full (100%) coverage**.
///
/// It activates every region layer and tiers their coverage (broad bases → rare peaks),
/// scatters patch sizes, spreads height-offset bands so occlusion lets each poke through,
/// and jitters edge/gain. It writes the Min and Max files together, always keeping Min ≤ Max
/// so the pair stays valid. Structural shapers (noise, Small/Large grids) get the generous
/// tiers; resource grids and small feature accents stay deliberately sparse.
///
/// Randomness is injected so callers can seed it (deterministic tests / reproducible sets)
/// or pass `SystemRandomNumberGenerator` for a fresh mix each click.
public enum SmartRegionMix {
    /// Coverage is never allowed to reach 1.0 — this is the "none at 100%" cap.
    private static let coverageCeiling = 0.8

    public static func apply<R: RandomNumberGenerator>(
        min mn: inout TkVoxelGeneratorData,
        max mx: inout TkVoxelGeneratorData,
        using rng: inout R
    ) {
        // Noise layers: the primary shapers. Tier 0 → broad base, tier 1 → rare peak.
        let noise: [WritableKeyPath<NoiseLayers, TkNoiseUberLayerData>] = [
            \.base, \.hill, \.mountain, \.rock, \.underWater, \.texture, \.elevation, \.continent
        ]
        for (i, kp) in noise.enumerated() {
            let t = tier(i, noise.count)
            mixNoise(&mn.noiseLayers[keyPath: kp], &mx.noiseLayers[keyPath: kp], tier: t, rng: &rng)
        }

        // Grid layers: Small/Large are structural (generous); the seven resources stay sparse.
        let structural: [WritableKeyPath<GridLayers, TkNoiseGridData>] = [\.small, \.large]
        for (i, kp) in structural.enumerated() {
            let t = tier(i, structural.count)
            mixGrid(&mn.gridLayers[keyPath: kp], &mx.gridLayers[keyPath: kp], coverage: (0.3, 0.55), tier: t, rng: &rng)
        }
        let resources: [WritableKeyPath<GridLayers, TkNoiseGridData>] = [
            \.resourcesHeridium, \.resourcesIridium, \.resourcesCopper, \.resourcesNickel,
            \.resourcesAluminium, \.resourcesGold, \.resourcesEmeril
        ]
        for (i, kp) in resources.enumerated() {
            let t = tier(i, resources.count)
            mixGrid(&mn.gridLayers[keyPath: kp], &mx.gridLayers[keyPath: kp], coverage: (0.08, 0.22), tier: t, rng: &rng)
        }

        // Features: scattered accents. Height bands spread so they don't all sit at one level.
        let features: [WritableKeyPath<Features, TkNoiseFeatureData>] = [
            \.river, \.crater, \.arches, \.archesSmall, \.blobs, \.blobsSmall, \.substance
        ]
        for (i, kp) in features.enumerated() {
            let t = tier(i, features.count)
            mixFeature(&mn.features[keyPath: kp], &mx.features[keyPath: kp], coverage: (0.15, 0.4), tier: t, rng: &rng)
        }

        // Caves: want to actually exist, so moderate coverage.
        mixFeature(&mn.caves.underground.mouth, &mx.caves.underground.mouth, coverage: (0.3, 0.6), tier: 0.2, rng: &rng)
        mixFeature(&mn.caves.underground.tunnel, &mx.caves.underground.tunnel, coverage: (0.35, 0.6), tier: 0.6, rng: &rng)
    }

    // MARK: - Per-layer mixing

    private static func mixNoise<R: RandomNumberGenerator>(
        _ a: inout TkNoiseUberLayerData, _ b: inout TkNoiseUberLayerData, tier t: Double, rng: inout R
    ) {
        a.active = true; b.active = true
        // Broad base (tier 0) tapering to rare peaks (tier 1).
        let cover = lerp(0.62, 0.16, t)
        pair(&a.regionRatio, &b.regionRatio, center: cover, spread: 0.08, clamp: clampRatio, rng: &rng)
        pair(&a.regionScale, &b.regionScale, center: Double.random(in: 2.5...13, using: &rng), spread: 2, clamp: clampScale, rng: &rng)
        pair(&a.regionGain, &b.regionGain, center: Double.random(in: 1.5...4.5, using: &rng), spread: 1, clamp: clampGain, rng: &rng)
        pair(&a.heightOffset, &b.heightOffset, center: heightCenter(t, rng: &rng), spread: 10, clamp: clampHeight, rng: &rng)
    }

    private static func mixGrid<R: RandomNumberGenerator>(
        _ a: inout TkNoiseGridData, _ b: inout TkNoiseGridData, coverage: (Double, Double), tier t: Double, rng: inout R
    ) {
        a.active = true; b.active = true
        let cover = lerp(coverage.1, coverage.0, t)
        pair(&a.regionRatio, &b.regionRatio, center: cover, spread: 0.06, clamp: clampRatio, rng: &rng)
        pair(&a.regionScale, &b.regionScale, center: Double.random(in: 2...12, using: &rng), spread: 2, clamp: clampScale, rng: &rng)
        pair(&a.heightOffset, &b.heightOffset, center: heightCenter(t, rng: &rng), spread: 10, clamp: clampHeight, rng: &rng)
    }

    private static func mixFeature<R: RandomNumberGenerator>(
        _ a: inout TkNoiseFeatureData, _ b: inout TkNoiseFeatureData, coverage: (Double, Double), tier t: Double, rng: inout R
    ) {
        a.active = true; b.active = true
        let cover = lerp(coverage.1, coverage.0, t)
        pair(&a.ratio, &b.ratio, center: cover, spread: 0.07, clamp: clampRatio, rng: &rng)
        pair(&a.regionSize, &b.regionSize, center: Double.random(in: 150...2200, using: &rng), spread: 250, clamp: clampSize, rng: &rng)
        pair(&a.heightOffset, &b.heightOffset, center: heightCenter(t, rng: &rng), spread: 12, clamp: clampHeight, rng: &rng)
    }

    // MARK: - Helpers

    /// Even 0…1 position of index `i` among `count` items (0 for a single item).
    private static func tier(_ i: Int, _ count: Int) -> Double {
        count <= 1 ? 0 : Double(i) / Double(count - 1)
    }

    private static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * min(max(t, 0), 1)
    }

    /// A distinct height-offset band per tier (low tiers sit low, high tiers poke up), jittered.
    private static func heightCenter<R: RandomNumberGenerator>(_ t: Double, rng: inout R) -> Double {
        lerp(-45, 95, t) + Double.random(in: -8...8, using: &rng)
    }

    /// Sets an ordered Min ≤ Max pair around `center` ± up to `spread`, clamped into range.
    private static func pair<R: RandomNumberGenerator>(
        _ a: inout Double, _ b: inout Double,
        center: Double, spread: Double, clamp: (Double) -> Double, rng: inout R
    ) {
        let lo = clamp(center - Double.random(in: 0...spread, using: &rng))
        let hi = clamp(center + Double.random(in: 0...spread, using: &rng))
        a = Swift.min(lo, hi)
        b = Swift.max(lo, hi)
    }

    private static func clampRatio(_ v: Double) -> Double { min(max(v, 0.05), coverageCeiling) }
    private static func clampScale(_ v: Double) -> Double { min(max(v, 0.95), 19.95) }
    private static func clampGain(_ v: Double) -> Double { min(max(v, 0), 10) }
    private static func clampSize(_ v: Double) -> Double { min(max(v, 10), 4000) }
    private static func clampHeight(_ v: Double) -> Double { min(max(v, -128), 128) }
}
