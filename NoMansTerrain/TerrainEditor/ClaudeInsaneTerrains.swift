import Foundation

/// One fully-realized "insane" terrain: a Min/Max pair plus the game slot it occupies in
/// the combined `voxelgeneratorsettings.MXML` and some human-facing flavor text.
struct InsaneTerrain: Identifiable, Sendable {
    let id: Int
    let displayName: String
    let blurb: String
    /// The game terrain slot (game order) this occupies in the combined file.
    let preset: TerrainPreset
    let min: TkVoxelGeneratorData
    let max: TkVoxelGeneratorData
}

/// "Claude's Insane Terrain" — a curated set of 31 deliberately bizarre terrains built by
/// pushing the engine well past the editor's known-safe slider bounds and leaning hard on
/// the SuperFormula / SuperPrimitive grid primitives (and their `…Random` variants).
///
/// Everything here is **deterministic**: each terrain is derived from a structurally
/// complete base terrain (the bundle's aggregated Min/Max) by a per-recipe transform driven
/// by a seeded RNG, so the set is identical every run. LODs are pinned to their max-safe
/// values (lower LODs break in-game), but otherwise the values are intentionally extreme.
enum ClaudeInsaneTerrains {
    static let setName = "Claude's Insane Terrain"

    /// Global spikiness dial, 0…1. At `1.0` the set is maximally unhinged; lower values pull
    /// the most aggressive drivers back toward documented-safe so spikes stay thicker than
    /// the voxel grid can mesh (very thin, high-frequency spikes tear holes in the terrain).
    /// Tuned to 0.7 after in-game gaps showed up at full tilt. Change this one number to
    /// dial the whole set hotter or tamer.
    static let intensity = 0.7

    /// Interpolates from a tame value (used as `intensity` → 0) to a wild value (`intensity`
    /// → 1). Used on the handful of fields that drive sub-voxel spike thinness.
    private static func hot(_ tame: Double, _ wild: Double) -> Double {
        tame + (wild - tame) * intensity
    }

    /// Builds all 31 insane terrains from a structurally-complete base (use the catalog's
    /// aggregated `globalMin`/`globalMax`). Pure and deterministic.
    static func generate(base: SendableTerrain) -> [InsaneTerrain] {
        let presets = TerrainPreset.all
        return specs.enumerated().map { index, spec in
            var rng = SeededGenerator(seed: stableSeed(spec.name))
            var mn = base.min
            var mx = base.max
            apply(spec, min: &mn, max: &mx, rng: &rng)
            return InsaneTerrain(
                id: index,
                displayName: String(format: "Claude #%02d · %@", index + 1, spec.name),
                blurb: spec.blurb,
                preset: presets[index % presets.count],
                min: mn,
                max: mx
            )
        }
    }

    /// Combined-file entries (game order) for the whole set.
    static func combinedEntries(base: SendableTerrain) -> [NMSPropertySerializer.CombinedEntry] {
        generate(base: base).map {
            NMSPropertySerializer.CombinedEntry(name: $0.preset.fileBaseName, min: $0.min, max: $0.max)
        }
    }

    // MARK: - Recipe transform

    private static func apply(
        _ spec: InsaneSpec,
        min mn: inout TkVoxelGeneratorData,
        max mx: inout TkVoxelGeneratorData,
        rng: inout SeededGenerator
    ) {
        // 1. Broad landscape noise — pushed past the documented envelope for wild relief.
        let noiseKPs: [WritableKeyPath<NoiseLayers, TkNoiseUberLayerData>] = [
            \.base, \.hill, \.mountain, \.rock, \.underWater, \.texture, \.elevation, \.continent
        ]
        for (role, kp) in noiseKPs.enumerated() {
            wildUber(&mn.noiseLayers[keyPath: kp], &mx.noiseLayers[keyPath: kp], spec: spec, role: role, rng: &rng)
        }

        // 2. Grid primitives — the star of the show: SuperFormula / SuperPrimitive shapes.
        wildGrid(&mn.gridLayers.small, &mx.gridLayers.small,
                 primary: spec.primaryGrid, secondary: spec.secondaryGrid, spec: spec, resource: false, rng: &rng)
        wildGrid(&mn.gridLayers.large, &mx.gridLayers.large,
                 primary: spec.primaryGrid, secondary: spec.secondaryGrid, spec: spec, resource: false, rng: &rng)

        // Resource grids become crazy little scattered shapes too (the `…Random` variants).
        let resKPs: [WritableKeyPath<GridLayers, TkNoiseGridData>] = [
            \.resourcesHeridium, \.resourcesIridium, \.resourcesCopper, \.resourcesNickel,
            \.resourcesAluminium, \.resourcesGold, \.resourcesEmeril
        ]
        for kp in resKPs {
            wildGrid(&mn.gridLayers[keyPath: kp], &mx.gridLayers[keyPath: kp],
                     primary: spec.secondaryGrid, secondary: spec.secondaryGrid, spec: spec, resource: true, rng: &rng)
        }

        // 3. Discrete features — arches, blobs, craters cranked up for set-piece chaos.
        wildFeatures(&mn.features, &mx.features, rng: &rng)

        // 4. Turn everything on, then pin every LOD to its max-safe value.
        TerrainEditorOperations.activateAll(&mn)
        TerrainEditorOperations.activateAll(&mx)
        mn = mn.applyingMaxLOD()
        mx = mx.applyingMaxLOD()
    }

    // MARK: - Layer mutators

    private static func wildUber(
        _ a: inout TkNoiseUberLayerData,
        _ b: inout TkNoiseUberLayerData,
        spec: InsaneSpec,
        role: Int,
        rng: inout SeededGenerator
    ) {
        let spiky = spec.theme.isSpiky
        let blobby = spec.theme.isBlobby

        setPair(&a, &b, \.noiseData.amplifyFeatures, 0.3, hot(0.5, 1.2), &rng)        // doc max 0.5
        let pSign = blobby ? -1.0 : 1.0
        setPair(&a, &b, \.noiseData.perturbFeatures, 0.3 * pSign, hot(0.6, 1.6) * pSign, &rng) // doc ±0.4
        // Ridges are the sharpest, thinnest features — don't pin them to full.
        a.noiseData.ridgeErosion = spiky ? hot(0.5, 1.0) : Double.random(in: 0...1, using: &rng)
        b.noiseData.ridgeErosion = hot(0.5, 1.0)
        setPair(&a, &b, \.noiseData.slopeErosion, 0.0, 1.0, &rng)
        if spiky {
            setPair(&a, &b, \.noiseData.sharpToRoundFeatures, 0.5, 1.0, &rng)
        } else if blobby {
            setPair(&a, &b, \.noiseData.sharpToRoundFeatures, -1.0, -0.4, &rng)
        } else {
            setPair(&a, &b, \.noiseData.sharpToRoundFeatures, -1.0, 1.0, &rng)
        }
        setPair(&a, &b, \.noiseData.altitudeErosion, 0.0, 0.5, &rng)          // doc max 0.25
        // Lacunarity × gain × octaves drive fine high-amplitude detail — the main cause of
        // sub-voxel thinness — so these get pulled back the hardest.
        setPair(&a, &b, \.noiseData.lacunarity, 2.0, hot(2.3, 3.2), &rng)     // doc max 2.2
        setPair(&a, &b, \.noiseData.gain, 0.5, hot(0.65, 0.88), &rng)         // doc max 0.6
        setPairInt(&a, &b, \.noiseData.octaves, 7, intensity > 0.85 ? 10 : 9, &rng) // cap (perf + detail)
        setPair(&a, &b, \.noiseData.remapFromMin, -1.5, 0.2, &rng)
        setPair(&a, &b, \.noiseData.remapFromMax, 0.4, 1.8, &rng)
        setPair(&a, &b, \.noiseData.remapToMin, -1.5, 0.0, &rng)
        setPair(&a, &b, \.noiseData.remapToMax, 0.8, 2.0, &rng)

        let reliefH = (role == 7 ? 1.6 : 1.0) * spec.relief                   // continent taller
        setPair(&a, &b, \.height, hot(90, 120) * reliefH, hot(170, 260) * reliefH, &rng) // doc max ~128
        setPair(&a, &b, \.heightOffset, -spec.floatAmount * 0.2, spec.floatAmount * 0.5, &rng)
        setPair(&a, &b, \.regionRatio, 0.6, 1.0, &rng)
        setPair(&a, &b, \.regionScale, 1.5, 12.0, &rng)
        setPair(&a, &b, \.regionGain, 1.0, 4.0, &rng)
        // Lower intensity → more post-smoothing, which fuses near-sub-voxel detail.
        setPair(&a, &b, \.smoothRadius, blobby ? 8 : hot(4, 0), blobby ? 20 : hot(10, 4), &rng)
        if spec.theme == .terraces {
            setPair(&a, &b, \.plateauStratas, 6, 16, &rng)
            setPairInt(&a, &b, \.plateauSharpness, 3, 4, &rng)
        }
        setPair(&a, &b, \.tileBlendMeters, 0, 24, &rng)
    }

    private static func wildGrid(
        _ a: inout TkNoiseGridData,
        _ b: inout TkNoiseGridData,
        primary: NoiseGridType,
        secondary: NoiseGridType,
        spec: InsaneSpec,
        resource: Bool,
        rng: inout SeededGenerator
    ) {
        a.active = true; b.active = true
        a.noiseGridType = primary; b.noiseGridType = secondary
        a.subtract = false
        b.subtract = (spec.theme == .vortex && !resource)

        // SuperFormula 1 — straight from the recipe (values may exceed doc bounds).
        // `formN1` near 0 makes razor-thin spikes; lower intensity raises that floor so the
        // shapes stay chunky enough to mesh without tearing.
        let n1Floor = Swift.max(spec.n1, hot(spec.n1, 0.8))
        setPair(&a, &b, \.superFormula1.formM, spec.m, spec.m + 1.5, &rng)
        setPair(&a, &b, \.superFormula1.formN1, n1Floor, n1Floor + 6, &rng)
        setPair(&a, &b, \.superFormula1.formN2, spec.n2, spec.n2 + 8, &rng)
        setPair(&a, &b, \.superFormula1.formN3, spec.n3, spec.n3 + 8, &rng)
        // SuperFormula 2 — a contrasting set so the two axes disagree (more alien).
        setPair(&a, &b, \.superFormula2.formM, spec.m * 0.5 + 1, spec.m * 0.5 + 3, &rng)
        setPair(&a, &b, \.superFormula2.formN1, 0.3, spec.n1 + 2, &rng)
        setPair(&a, &b, \.superFormula2.formN2, -8, spec.n2 + 4, &rng)
        setPair(&a, &b, \.superFormula2.formN3, -8, spec.n3 + 4, &rng)
        // SuperPrimitive — normalized 0…1 dimensions, varied widely.
        setPair(&a, &b, \.superPrimitive.width, 0.25, 1.0, &rng)
        setPair(&a, &b, \.superPrimitive.height, 0.25, 1.0, &rng)
        setPair(&a, &b, \.superPrimitive.depth, 0.25, 1.0, &rng)
        setPair(&a, &b, \.superPrimitive.thickness, 0.1, 1.0, &rng)
        setPair(&a, &b, \.superPrimitive.cornerRadiusXY, 0.0, 1.0, &rng)
        setPair(&a, &b, \.superPrimitive.cornerRadiusZ, 0.0, 1.0, &rng)
        setPair(&a, &b, \.superPrimitive.bottomRadiusOffset, 0.0, 1.0, &rng)

        let s = resource ? 0.4 : 1.0
        setPair(&a, &b, \.minWidth, 60 * s, 200 * s, &rng)
        setPair(&a, &b, \.maxWidth, 250 * s, 600 * s, &rng)
        setPair(&a, &b, \.minHeight, 30 * s, 120 * s, &rng)
        // Tall + thin = needles that tear; cap the height as intensity drops.
        setPair(&a, &b, \.maxHeight, hot(130, 150) * s, hot(240, 400) * s, &rng)

        if spec.theme.isFloating && !resource {
            setPair(&a, &b, \.minHeightOffset, spec.floatAmount * 0.4, spec.floatAmount * 0.7, &rng) // beyond ±128
            setPair(&a, &b, \.maxHeightOffset, spec.floatAmount * 0.7, spec.floatAmount, &rng)
            setPair(&a, &b, \.heightOffset, spec.floatAmount * 0.3, spec.floatAmount * 0.8, &rng)
        } else {
            setPair(&a, &b, \.minHeightOffset, -40, 0, &rng)
            setPair(&a, &b, \.maxHeightOffset, 0, 60, &rng)
            setPair(&a, &b, \.heightOffset, -20, 40, &rng)
        }

        setPair(&a, &b, \.yaw, 0, 90, &rng)
        setPair(&a, &b, \.pitch, 0, 90, &rng)
        setPair(&a, &b, \.roll, 0, 90, &rng)
        setPair(&a, &b, \.varyYaw, 0, spec.twist, &rng)   // twist can exceed doc 90 → tumbling
        setPair(&a, &b, \.varyPitch, 0, spec.twist, &rng)
        setPair(&a, &b, \.varyRoll, 0, spec.twist, &rng)

        setPair(&a, &b, \.regionRatio, resource ? 0.2 : 0.55, resource ? 0.5 : 1.0, &rng)
        setPair(&a, &b, \.regionScale, 1.0, resource ? 6 : 14, &rng)
        setPair(&a, &b, \.smoothRadius, spec.theme.isBlobby ? 10 : 0, spec.theme.isBlobby ? 40 : 4, &rng)

        if isRandom(primary) || isRandom(secondary) {
            a.randomPrimitive = 1.0; b.randomPrimitive = 1.0
        } else {
            setPair(&a, &b, \.randomPrimitive, 0, 1, &rng)
        }
        setPair(&a, &b, \.tileBlendMeters, 0, 16, &rng)

        a.swapZY = Bool.random(using: &rng); b.swapZY = a.swapZY
        a.hemisphere = Bool.random(using: &rng); b.hemisphere = Bool.random(using: &rng)

        let vt = spec.palette.randomElement(using: &rng) ?? .rock
        a.voxelType = TkNoiseVoxelTypeEnum(noiseVoxelType: vt)
        b.voxelType = TkNoiseVoxelTypeEnum(noiseVoxelType: vt)

        // Turbulence breathes life into the otherwise-clean primitives.
        a.turbulenceNoiseLayer.active = true; b.turbulenceNoiseLayer.active = true
        setPair(&a, &b, \.turbulenceNoiseLayer.noiseData.perturbFeatures, 0.3, 1.4, &rng)
        setPair(&a, &b, \.turbulenceNoiseLayer.noiseData.amplifyFeatures, 0.3, 1.2, &rng)
        setPair(&a, &b, \.turbulenceNoiseLayer.height, 40, 160, &rng)
    }

    private static func wildFeatures(
        _ a: inout Features,
        _ b: inout Features,
        rng: inout SeededGenerator
    ) {
        let kps: [WritableKeyPath<Features, TkNoiseFeatureData>] = [
            \.river, \.crater, \.arches, \.archesSmall, \.blobs, \.blobsSmall, \.substance
        ]
        for kp in kps {
            a[keyPath: kp].active = true
            b[keyPath: kp].active = true
            setPair(&a[keyPath: kp], &b[keyPath: kp], \.width, 20, 120, &rng)
            setPair(&a[keyPath: kp], &b[keyPath: kp], \.height, 20, 100, &rng)
            setPair(&a[keyPath: kp], &b[keyPath: kp], \.ratio, 0.3, 1.0, &rng)
            setPair(&a[keyPath: kp], &b[keyPath: kp], \.regionSize, 40, 2000, &rng)
            setPair(&a[keyPath: kp], &b[keyPath: kp], \.heightVarianceAmplitude, 10, 128, &rng)
        }
    }

    // MARK: - Pair helpers (assign min ≤ max from a seeded range)

    private static func setPair<Root>(
        _ a: inout Root, _ b: inout Root,
        _ kp: WritableKeyPath<Root, Double>,
        _ lo: Double, _ hi: Double,
        _ rng: inout SeededGenerator
    ) {
        let lo2 = Swift.min(lo, hi), hi2 = Swift.max(lo, hi)
        let x = Double.random(in: lo2...hi2, using: &rng)
        let y = Double.random(in: lo2...hi2, using: &rng)
        a[keyPath: kp] = Swift.min(x, y)
        b[keyPath: kp] = Swift.max(x, y)
    }

    private static func setPairInt<Root>(
        _ a: inout Root, _ b: inout Root,
        _ kp: WritableKeyPath<Root, Int>,
        _ lo: Int, _ hi: Int,
        _ rng: inout SeededGenerator
    ) {
        let x = Int.random(in: lo...hi, using: &rng)
        let y = Int.random(in: lo...hi, using: &rng)
        a[keyPath: kp] = Swift.min(x, y)
        b[keyPath: kp] = Swift.max(x, y)
    }

    private static func isRandom(_ t: NoiseGridType) -> Bool {
        t == .superFormulaRandom || t == .superPrimitiveRandom
    }
}

// MARK: - Recipe data

extension ClaudeInsaneTerrains {
    enum Theme: Sendable {
        case spires, blobs, terraces, floatingIslands, canyons, lattice, vortex, reef

        var isSpiky: Bool { [.spires, .lattice, .reef, .canyons].contains(self) }
        var isBlobby: Bool { [.blobs, .floatingIslands, .vortex].contains(self) }
        var isFloating: Bool { [.floatingIslands, .vortex, .lattice].contains(self) }
    }

    /// A compact recipe; the engine above expands these dials into hundreds of fields.
    struct InsaneSpec: Sendable {
        let name: String
        let blurb: String
        let primaryGrid: NoiseGridType
        let secondaryGrid: NoiseGridType
        let m: Double, n1: Double, n2: Double, n3: Double
        let floatAmount: Double
        let relief: Double
        let twist: Double
        let theme: Theme
        let palette: [NoiseVoxelType]
    }

    /// Exactly 31 — one per game terrain slot (`TerrainPreset.all.count`).
    static let specs: [InsaneSpec] = [
        InsaneSpec(name: "Crystalline Cathedral", blurb: "Towering faceted crystal spires in 6-fold symmetry.",
                   primaryGrid: .superFormula, secondaryGrid: .superFormulaRandom, m: 6, n1: 0.3, n2: 0.3, n3: 0.3,
                   floatAmount: 180, relief: 1.3, twist: 30, theme: .lattice, palette: [.rock, .substance2, .randomRock]),
        InsaneSpec(name: "Möbius Sea", blurb: "Twisting ribbon landmasses warping over an endless ocean.",
                   primaryGrid: .superFormula02, secondaryGrid: .superFormulaRandom, m: 2, n1: 1, n2: 1, n3: 1,
                   floatAmount: 140, relief: 1.1, twist: 140, theme: .vortex, palette: [.sand, .base, .substance1]),
        InsaneSpec(name: "Fractal Anemone Fields", blurb: "Branching anemone reefs bristling everywhere.",
                   primaryGrid: .superFormulaRandom, secondaryGrid: .superFormulaRandom, m: 8, n1: 1, n2: 8, n3: 8,
                   floatAmount: 90, relief: 1.4, twist: 80, theme: .reef, palette: [.substance3, .rock, .randomRockOrSubstance]),
        InsaneSpec(name: "Inverted Mountain Mirror", blurb: "Mountains hanging down into mirror-image canyons.",
                   primaryGrid: .superPrimitive, secondaryGrid: .superPrimitiveRandom, m: 4, n1: 4, n2: 4, n3: 4,
                   floatAmount: 60, relief: 1.6, twist: 20, theme: .canyons, palette: [.mountain, .rock, .base]),
        InsaneSpec(name: "Klein Bottle Badlands", blurb: "Self-intersecting glass dunes that fold through themselves.",
                   primaryGrid: .superFormula03, secondaryGrid: .superFormulaRandom, m: 3, n1: 0.6, n2: 0.6, n3: 0.6,
                   floatAmount: 120, relief: 1.2, twist: 160, theme: .vortex, palette: [.sand, .substance2]),
        InsaneSpec(name: "Starfish Archipelago", blurb: "Five-armed star islands floating in formation.",
                   primaryGrid: .superFormula, secondaryGrid: .superFormulaRandom, m: 5, n1: 0.4, n2: 1.7, n3: 1.7,
                   floatAmount: 220, relief: 1.0, twist: 40, theme: .floatingIslands, palette: [.base, .sand, .substance1]),
        InsaneSpec(name: "Gravity-Defying Pylons", blurb: "Colossal rounded pylons hanging in mid-air.",
                   primaryGrid: .superPrimitive, secondaryGrid: .superPrimitiveRandom, m: 4, n1: 10, n2: 10, n3: 10,
                   floatAmount: 280, relief: 1.1, twist: 25, theme: .floatingIslands, palette: [.rock, .mountain]),
        InsaneSpec(name: "Coral Brain Coral", blurb: "Convoluted blobby coral brains the size of hills.",
                   primaryGrid: .superFormulaRandom, secondaryGrid: .superFormulaRandom, m: 7, n1: 2, n2: 6, n3: 6,
                   floatAmount: 70, relief: 1.2, twist: 60, theme: .blobs, palette: [.substance1, .substance3, .randomRock]),
        InsaneSpec(name: "Hexagonal Hex Hell", blurb: "A world tiled in interlocking hexagonal monoliths.",
                   primaryGrid: .superFormula, secondaryGrid: .superFormula04, m: 6, n1: 8, n2: 8, n3: 8,
                   floatAmount: 100, relief: 1.3, twist: 15, theme: .lattice, palette: [.rock, .base]),
        InsaneSpec(name: "Twisting Pillar Forest", blurb: "Endless corkscrewing pillars reaching skyward.",
                   primaryGrid: .superPrimitiveRandom, secondaryGrid: .superPrimitiveRandom, m: 3, n1: 12, n2: 4, n3: 4,
                   floatAmount: 90, relief: 1.5, twist: 170, theme: .spires, palette: [.rock, .mountain, .randomRock]),
        InsaneSpec(name: "Diamond Lattice World", blurb: "A crystalline diamond lattice grown to planetary scale.",
                   primaryGrid: .superFormula04, secondaryGrid: .superFormulaRandom, m: 4, n1: 0.2, n2: 0.2, n3: 0.2,
                   floatAmount: 160, relief: 1.2, twist: 35, theme: .lattice, palette: [.substance2, .rock]),
        InsaneSpec(name: "Screaming Spires", blurb: "Razor-thin needle spires stabbing at the clouds.",
                   primaryGrid: .superFormula, secondaryGrid: .superFormulaRandom, m: 3, n1: 0.15, n2: 0.15, n3: 0.15,
                   floatAmount: 80, relief: 1.7, twist: 20, theme: .spires, palette: [.rock, .mountain]),
        InsaneSpec(name: "Bubblewrap Plains", blurb: "Infinite plains of squishy popping bubbles.",
                   primaryGrid: .superPrimitive, secondaryGrid: .superPrimitiveRandom, m: 4, n1: 20, n2: 20, n3: 20,
                   floatAmount: 40, relief: 0.9, twist: 10, theme: .blobs, palette: [.base, .substance1]),
        InsaneSpec(name: "Tesseract Terraces", blurb: "Stacked impossible-geometry terraces marching upward.",
                   primaryGrid: .superPrimitiveRandom, secondaryGrid: .superPrimitiveRandom, m: 4, n1: 6, n2: 6, n3: 6,
                   floatAmount: 70, relief: 1.4, twist: 25, theme: .terraces, palette: [.rock, .base, .mountain]),
        InsaneSpec(name: "Whirlpool Vortex Land", blurb: "The whole crust spiraling into a colossal whirlpool.",
                   primaryGrid: .superFormula05, secondaryGrid: .superFormulaRandom, m: 2, n1: 0.5, n2: 2, n3: 2,
                   floatAmount: 130, relief: 1.3, twist: 180, theme: .vortex, palette: [.sand, .substance3]),
        InsaneSpec(name: "Toothpaste Extrusions", blurb: "Squeezed ribbons of rock oozing from the ground.",
                   primaryGrid: .superPrimitive, secondaryGrid: .superPrimitiveRandom, m: 3, n1: 14, n2: 2, n3: 2,
                   floatAmount: 60, relief: 1.4, twist: 120, theme: .spires, palette: [.substance2, .rock]),
        InsaneSpec(name: "Origami Crater Garden", blurb: "Crisply folded paper-fold craters in neat rows.",
                   primaryGrid: .superFormula06, secondaryGrid: .superFormulaRandom, m: 5, n1: 9, n2: 9, n3: 9,
                   floatAmount: 50, relief: 1.1, twist: 30, theme: .terraces, palette: [.sand, .base]),
        InsaneSpec(name: "Gothic Spike Reef", blurb: "Cathedral-sharp spikes erupting from a drowned reef.",
                   primaryGrid: .superFormulaRandom, secondaryGrid: .superFormulaRandom, m: 7, n1: 0.3, n2: 0.5, n3: 0.5,
                   floatAmount: 110, relief: 1.6, twist: 50, theme: .reef, palette: [.rock, .substance3, .randomRock]),
        InsaneSpec(name: "Floating Donut Holes", blurb: "Hovering toruses with carved-out centers.",
                   primaryGrid: .superFormula, secondaryGrid: .superFormulaRandom, m: 2, n1: 3, n2: 0.5, n3: 0.5,
                   floatAmount: 240, relief: 1.0, twist: 45, theme: .vortex, palette: [.base, .substance1]),
        InsaneSpec(name: "Sawblade Canyons", blurb: "Serrated sawtooth ridgelines slicing deep canyons.",
                   primaryGrid: .superFormula07, secondaryGrid: .superFormulaRandom, m: 9, n1: 0.4, n2: 0.4, n3: 0.4,
                   floatAmount: 70, relief: 1.6, twist: 20, theme: .canyons, palette: [.mountain, .rock]),
        InsaneSpec(name: "Mushroom Megalith", blurb: "Giant capped mushroom monoliths casting long shadows.",
                   primaryGrid: .superPrimitive, secondaryGrid: .superPrimitiveRandom, m: 4, n1: 8, n2: 16, n3: 2,
                   floatAmount: 200, relief: 1.2, twist: 30, theme: .floatingIslands, palette: [.substance1, .rock]),
        InsaneSpec(name: "Shattered Glass Steppes", blurb: "Jagged shards of fractured glass stepping to the horizon.",
                   primaryGrid: .superFormula08, secondaryGrid: .superFormulaRandom, m: 8, n1: 0.25, n2: 0.6, n3: 0.6,
                   floatAmount: 90, relief: 1.4, twist: 40, theme: .terraces, palette: [.substance2, .rock, .base]),
        InsaneSpec(name: "Pinwheel Pinnacles", blurb: "Spinning pinwheel rock formations frozen mid-twirl.",
                   primaryGrid: .superFormulaRandom, secondaryGrid: .superFormulaRandom, m: 5, n1: 0.5, n2: 3, n3: 3,
                   floatAmount: 120, relief: 1.3, twist: 175, theme: .spires, palette: [.rock, .mountain, .randomRock]),
        InsaneSpec(name: "Bone Forest Cathedral", blurb: "Pale rib-and-spine bone arches vaulting overhead.",
                   primaryGrid: .superPrimitiveRandom, secondaryGrid: .superPrimitiveRandom, m: 3, n1: 10, n2: 1, n3: 1,
                   floatAmount: 150, relief: 1.5, twist: 60, theme: .spires, palette: [.base, .substance2]),
        InsaneSpec(name: "Liquid Metal Dunes", blurb: "Rolling chrome dunes with mercury-smooth crests.",
                   primaryGrid: .superFormula01, secondaryGrid: .superFormulaRandom, m: 4, n1: 30, n2: 30, n3: 30,
                   floatAmount: 50, relief: 1.0, twist: 25, theme: .blobs, palette: [.substance3, .sand]),
        InsaneSpec(name: "Antler Coral Maze", blurb: "Interlocking antler-coral walls forming a living maze.",
                   primaryGrid: .superFormulaRandom, secondaryGrid: .superFormulaRandom, m: 6, n1: 0.4, n2: 4, n3: 1,
                   floatAmount: 80, relief: 1.4, twist: 90, theme: .reef, palette: [.substance1, .rock, .randomRockOrSubstance]),
        InsaneSpec(name: "Inside-Out Sphereworld", blurb: "Concave spherical shells you stand inside of.",
                   primaryGrid: .superPrimitive, secondaryGrid: .superPrimitiveRandom, m: 4, n1: 40, n2: 40, n3: 40,
                   floatAmount: 260, relief: 1.1, twist: 35, theme: .floatingIslands, palette: [.base, .rock]),
        InsaneSpec(name: "Razorback Ridgelines", blurb: "Endless knife-edge ridges with sheer drops either side.",
                   primaryGrid: .superFormula, secondaryGrid: .superFormulaRandom, m: 2, n1: 0.2, n2: 0.2, n3: 0.2,
                   floatAmount: 60, relief: 1.7, twist: 15, theme: .canyons, palette: [.mountain, .rock]),
        InsaneSpec(name: "Honeycomb Heavens", blurb: "Floating honeycomb cells stacked into sky-hives.",
                   primaryGrid: .superFormula, secondaryGrid: .superFormulaRandom, m: 6, n1: 12, n2: 12, n3: 12,
                   floatAmount: 230, relief: 1.2, twist: 20, theme: .lattice, palette: [.substance2, .base]),
        InsaneSpec(name: "Spiral Nautilus Cliffs", blurb: "Logarithmic nautilus-shell cliffs winding inward.",
                   primaryGrid: .superFormula02, secondaryGrid: .superFormulaRandom, m: 2, n1: 1.2, n2: 0.8, n3: 0.8,
                   floatAmount: 110, relief: 1.4, twist: 150, theme: .vortex, palette: [.sand, .rock, .substance1]),
        InsaneSpec(name: "Eldritch Tentacle Basin", blurb: "A basin writhing with colossal grasping tentacles.",
                   primaryGrid: .superFormulaRandom, secondaryGrid: .superFormulaRandom, m: 5, n1: 0.6, n2: 5, n3: 0.4,
                   floatAmount: 100, relief: 1.6, twist: 130, theme: .reef, palette: [.substance3, .randomRock, .cave]),
    ]
}

// MARK: - Deterministic RNG

/// SplitMix64 — a tiny deterministic generator so the insane set is byte-stable per run.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

/// FNV-1a 64-bit — a stable string hash (Swift's `Hasher` is per-run randomized).
func stableSeed(_ s: String) -> UInt64 {
    var h: UInt64 = 0xCBF29CE484222325
    for byte in s.utf8 { h = (h ^ UInt64(byte)) &* 0x0000_0001_0000_01B3 }
    return h
}
