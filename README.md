# NoMansTerrain — Terrain Settings Field Reference

A best-effort explanation of what every field in No Man's Sky's
`VoxelGeneratorSettings` (the data this app edits) actually does to the planet you
fly down to.

> [!IMPORTANT]
> **How confident is any given line below?** Hello Games has never published this
> file's spec, so most of this is reconstructed from three things: (1) the community
> reverse-engineering on the modding wikis, (2) the published math behind NMS's noise
> function, and (3) the field names + the value ranges observed across the 31 bundled
> terrain files. Each entry is tagged:
>
> - ✅ **Documented** — confirmed by the NMS modding community or by the algorithm's author.
> - 🔶 **Inferred** — strong guess from the field name + how values vary across the real files.
> - ❓ **Speculative** — low confidence; treat as a hypothesis to test in-game.

---

## 1. The big picture: how NMS builds a planet

NMS terrain is **not** a heightmap. It's a **voxel density field** sampled in 3D, which
is why you get caves, overhangs, arches and floating islands that a 2D heightmap can't
represent. The surface you see is the isosurface (the "zero crossing") of that field,
meshed at runtime per-chunk with level-of-detail (LOD).

The density field is the **sum of many layers of noise stacked on top of each other**:

```
final density(x,y,z) =
      Σ NoiseLayers   (the broad landscape: continents, hills, mountains, rock…)
    + Σ GridLayers     (repeating structured shapes: pillars, floating islands, ore deposits…)
    + Σ Features        (discrete set-pieces: rivers, craters, arches, blobs…)
    + Caves             (carved out / subtracted)
    ± SeaLevel / building / smoothing adjustments
```

Each layer can **add** material or **subtract** it (`Subtract = true` carves, e.g. rivers
and caves), and each layer is gated by an `Active` flag and an LOD cap.

**Min vs Max.** ✅ Every terrain ships as a *pair* of full settings — a **Min** file and a
**Max** file. For each numeric field the game picks a value somewhere between the Min and
Max for a given planet (seeded by the planet), so one terrain "type" yields a *family* of
related planets. If Min == Max for a field, that field is fixed. This is why this app edits
everything as a Min/Max pair. *(See [the Step Mods terrain tutorial](https://stepmodifications.org/wiki/NoMansSky:Tutorials/Terrain_Generation).)*

**The noise function itself.** ✅ NMS's per-layer noise is the "**uber noise**" function
co-developed by **Giliam de Carpentier** (who worked with Hello Games). It's a fractal
(fBm) noise with built-in *erosion* terms — slope erosion, altitude erosion, ridge
erosion — plus domain warping. That published work is the Rosetta Stone for the
`NoiseData` fields below. See [de Carpentier on procedural terrain](https://www.decarpentier.nl/scape-procedural-extensions)
and the [GDC 2017 "Continuous World Generation in No Man's Sky" talk](https://www.gdcvault.com/play/1024265/Continuous-World-Generation-in-No).

---

## 2. Global / root settings — `TkVoxelGeneratorData`

These are the "General" tab fields: planet-wide scalars applied after the layers are summed.

| Field | Confidence | What it does |
|---|---|---|
| `BaseSeed` | ✅ | The seed feeding all the noise. `NONE` lets the game seed per-planet; a fixed number pins the shape so every planet of this type looks identical. |
| `SeaLevel` | ✅ | Height of the water plane (in the density field's units). Raise it to drown more land; lower it to expose seabed. Interacts with `UnderWater` noise and `WaterFade`. |
| `BeachHeight` | 🔶 | Vertical band above `SeaLevel` rendered/textured as beach (sand transition). Larger = wider shoreline. |
| `NoSeaBaseLevel` | 🔶 | The "ground floor" height used on planets that have **no** ocean, so dead/airless worlds still have a sensible base elevation. |
| `BuildingVoxelType` | 🔶 | Which material (see *Voxel Types*) the terrain flattens/retextures to where a building is placed. |
| `ResourceVoxelType` | 🔶 | Material used for the deposits produced by the `Resources_*` grid layers. |
| `MinimumCaveDepth` | 🔶 | Caves won't generate above this depth — keeps tunnels from breaking the surface everywhere. |
| `CaveRoofSmoothingDist` | 🔶 | Distance over which cave ceilings are smoothed, so roofs aren't jagged. |
| `MaximumSeaLevelCaveDepth` | 🔶 | How deep below sea level caves are still allowed — limits flooded caves. |
| `BuildingTextureRadius` | 🔶 | Radius around a building within which terrain is retextured (to `BuildingVoxelType`). |
| `BuildingSmoothingRadius` | 🔶 | Radius around a building within which terrain is flattened so structures sit on level ground. |
| `BuildingSmoothingHeight` | 🔶 | Vertical extent of that flattening. |
| `WaterFadeInDistance` | ❓ | Distance over which water visually fades in (shoreline transparency / horizon water pop-in). |

> [!NOTE]
> The bundled files all use `BuildingSmoothingRadius = 150`, which is why the app's
> "valid range" for it looks oddly narrow — there's no documented absolute limit, so the
> editor pads ±25% around the only value ever observed. Don't read those padded bounds as
> hard engine limits.

---

## 3. NoiseLayers — the landscape shape (`TkNoiseUberLayerData` ×8)

✅ These are the broad strokes of the world. There are 8 layers, and the community has
matched their order to the `GcTerrainControls` block found in decompiled biome files:

| Layer | Confidence | Role |
|---|---|---|
| `Base` | ✅ | General overall terrain shape — the foundation everything else sits on. |
| `Hill` | ✅ | Rolling hills / mid-frequency undulation. |
| `Mountain` | ✅ | Large relief. **Note:** often produces *sharp points* rather than what you'd picture as a "mountain." |
| `Rock` | ✅ | Rocky detail / boulder-scale relief. |
| `UnderWater` | ✅ | Shapes the seabed below `SeaLevel`. |
| `Texture` | ✅ | Fine surface detail used to drive texturing/micro-relief. |
| `Elevation` | 🔶 | Broad altitude bias — pushes whole regions up/down. |
| `Continent` | 🔶 | Lowest-frequency layer: defines continents vs. oceans (note its `PlateauRegionSize` is set differently from the others in the files). |

Each layer is a `TkNoiseUberLayerData`, which wraps a **`NoiseData`** block (the actual
noise math) plus **placement/shaping** controls.

### 3a. `NoiseData` — the uber-noise parameters

These map to de Carpentier's uber noise. Ranges in parentheses are what's observed across
the bundled files.

| Field | Confidence | What it does |
|---|---|---|
| `Octaves` (0–10) | ✅ | How many noise layers are summed. More octaves = more fine detail (and more cost). |
| `Lacunarity` (~2) | ✅ | Frequency multiplier per octave. Higher → detail packed at finer scales. ~2 is standard fBm. |
| `Gain` (~0.5) | ✅ | Amplitude multiplier per octave (a.k.a. persistence/roughness). Higher → rougher, noisier terrain; lower → smoother. |
| `SlopeErosion` (0 or 1) | ✅ | de Carpentier's **slope erosion**: dampens added detail on steep slopes (material "slides off"), producing smoother valleys and flowing slopes. Mostly a 0/1 on-off in the files. |
| `AltitudeErosion` (0–0.25) | ✅ | **Altitude erosion**: reduces amplitude based on height, flattening terrain toward an altitude — gives plateaus/mesas a settled look. |
| `RidgeErosion` (0 or 1) | ✅ | **Ridge erosion**: sharpens noise into ridgelines (the `1−|n|` trick), creating crisp mountain ridges/canyon walls. |
| `SlopeGain` (-0.3–0.9) | 🔶 | Shapes how strongly slope feeds the slope-erosion curve (steepness response). |
| `SlopeBias` (-0.2–0.5) | 🔶 | Offsets the slope-erosion curve — the slope at which erosion kicks in. |
| `SharpToRoundFeatures` (-1, 0, 1) | 🔶 | Blends feature character from **billowy/rounded** (`abs` noise) to **sharp/ridged**. −1 vs +1 = two opposite stylings. |
| `AmplifyFeatures` (0–0.5) | 🔶 | Boosts feature amplitude — exaggerates the bumps this layer contributes. |
| `PerturbFeatures` (-0.1–0.21) | ✅ | **Domain warping** amount: distorts the sample coordinates so shapes swirl and look organic instead of grid-aligned. |
| `Remap From Min` / `Remap From Max` | 🔶 | Input window of a remap (think Levels/Curves): which part of the raw noise range is kept. Narrowing it increases contrast. |
| `Remap To Min` / `Remap To Max` | 🔶 | Output window of that remap: the height range the kept noise is stretched into. Controls how tall/clamped the layer ends up. |
| `DebugNoiseType` | ❓ | Dev/debug noise selector (`Uber`/`Plane`/`Check`/`Sine`). Should be `Uber` in shipping data; the others are diagnostic patterns. |

### 3b. Placement & shaping (`TkNoiseUberLayerData` wrapper)

| Field | Confidence | What it does |
|---|---|---|
| `Active` | ✅ | Master on/off for the layer. |
| `MaximumLOD` (1–4) | ✅ | Highest detail level the layer renders at. **Lower values make the layer drop out at distance/low detail and cause visible terrain "popping"/seams — which is why this app has a "lock LOD to max."** |
| `Subtract` | ✅ | If true, the layer *carves* material instead of adding it (used for rivers/caves-like cuts). |
| `VoxelType` | 🔶 | Material this layer paints (see *Voxel Types*). |
| `Height` (1.27–128.27) | 🔶 | Vertical scale/amplitude of the layer's contribution. |
| `Width` (0–9999) | 🔶 | Horizontal scale of the layer (feature size in meters). |
| `RegionRatio` (0.2–1) | 🔶 | Fraction of the world where this layer is allowed to appear — how patchy vs. global it is. |
| `RegionScale` (1–5) | 🔶 | Size of those regions (how big each patch is). |
| `RegionGain` (1–3) | 🔶 | Intensity/contrast of the region mask. |
| `SmoothRadius` (0–20) | 🔶 | Post-smoothing applied to this layer's output. |
| `HeightOffset` (−128–128) | 🔶 | Shifts the layer up/down. Critical for grid layers (see floating-islands note). |
| `Offset` | 🔶 | Reference frame the offset is measured from (`Base`/`All`/`Zero`/`SeaLevel`). |
| `WaterFade` | 🔶 | Whether the layer fades `Above`, `Below`, or ignores (`None`) the water line. |
| `PlateauStratas` (0–2.49) | ❓ | Number/strength of terracing "steps" (stratified plateaus / banded cliffs). |
| `PlateauSharpness` (1–4) | ❓ | How crisp those terrace steps are. |
| `PlateauRegionSize` (0 / 100 / 1000) | ❓ | Size of plateau regions; note it's set differently for `Continent` vs. others. |
| `SeedOffset` (0–3) | 🔶 | Per-layer seed nudge so layers don't all share the same pattern. |
| `TileBlendMeters` (0–48) | 🔶 | Blend distance between adjacent noise tiles to hide tiling seams. |

---

## 4. GridLayers — structured shapes & resources (`TkNoiseGridData` ×9)

✅ Grid layers place **repeating, structured geometry** rather than organic noise: terrain
pillars, floating islands, and ore deposits. Order (per the wiki):

| Layer | Confidence | Role |
|---|---|---|
| `Small` | ✅ | Small columns/pillars (or small floating islands). |
| `Large` | ✅ | Large pillars **or floating islands** — which one depends on `HeightOffset` and whether the `TurbulenceNoiseLayer` is `Active`. Floating islands are typically `Active = false` turbulence. |
| `Resources_Heridium` … `Resources_Emeril` | ✅ | The 7 ore-deposit grids. Each scatters its mineral as deposits using the same grid machinery. |

Grid-specific fields:

| Field | Confidence | What it does |
|---|---|---|
| `NoiseGridType` | ✅ | The *shape primitive* placed at each grid point: `Sphere`, `Cube`, `Cone`, `Torus`, `Cylinder`, `Capsule`, `Corridor`, `Pipe`, `Puck`, a **SuperFormula** shape, a **SuperPrimitive**, or `File`. |
| `Filename` | 🔶 | Asset path used when `NoiseGridType = File`. |
| `MinWidth`/`MaxWidth` (0–9999) | 🔶 | Range of shape widths (game picks within). |
| `MinHeight`/`MaxHeight` (0–999) | 🔶 | Range of shape heights. |
| `MinHeightOffset`/`MaxHeightOffset`/`HeightOffset` (−128–128) | 🔶 | Vertical placement range + base offset. **High positive offset → shapes float (islands); near-ground → pillars.** |
| `SwapZY` | ❓ | Swaps Z/Y axes — reorients the primitive (e.g. lay a cylinder on its side). |
| `Hemisphere` | ❓ | Use only half the primitive (dome instead of sphere, etc.). |
| `RegionRatio` (0–1) / `RegionScale` (1–5) | 🔶 | How often and how large the regions containing these shapes are. |
| `Yaw`/`Pitch`/`Roll` (0–90) | 🔶 | Fixed orientation of the placed shapes. |
| `VaryYaw`/`VaryPitch`/`VaryRoll` (0–90) | 🔶 | Random orientation jitter added per instance. |
| `SmoothRadius` (0–20) | 🔶 | Smoothing applied to the placed shapes. |
| `RandomPrimitive` (0–1) | ❓ | Probability of randomizing which primitive is used per instance. |
| `SeedOffset` | 🔶 | Per-layer seed nudge. |
| `TurbulenceNoiseLayer` | ✅ | A **single** uber-noise layer (same structure as §3) that warps/breaks up the grid shapes — turns clean geometric pillars into natural-looking columns, controls floating-island shaping. |
| `SuperFormula1` / `SuperFormula2` | ✅ | Parameters for the Gielis superformula shape (see §6). Two are blended. Only relevant when `NoiseGridType` is a SuperFormula variant. |
| `SuperPrimitive` | 🔶 | Parameters for the rounded-box "superprimitive" shape (see §6). Separate from SuperFormula. |
| `TileBlendMeters` (0–16) | 🔶 | Seam-blend distance. |

---

## 5. Features — discrete set-pieces (`TkNoiseFeatureData` ×7)

✅ Features are scattered, individual landforms. Order (per the wiki):

| Feature | Confidence | Role |
|---|---|---|
| `River` | ✅ | Carved waterways (`Subtract`/`Trench` true). |
| `Crater` | ✅ | Impact craters. |
| `Arches` / `ArchesSmall` | ✅ | Natural rock arches (large + small). |
| `Blobs` / `BlobsSmall` | ✅ | Rounded blob landforms (boulders/mounds). |
| `Substance` | ✅ | Scattered substance/material deposits. |

Feature fields:

| Field | Confidence | What it does |
|---|---|---|
| `FeatureType` | 🔶 | `Tube` (elongated, e.g. rivers/arches) vs `Blob` (rounded, e.g. craters/blobs). |
| `Trench` | 🔶 | Cuts a connected channel rather than isolated pits (rivers). |
| `Width` (1–128) / `Height` (1–100) | 🔶 | Feature size. |
| `Octaves` | 🔶 | Noise detail used to shape the feature's edges. |
| `RegionSize` (10–4000) | 🔶 | How spread out instances are (bigger = rarer/larger spacing). |
| `Ratio` (0–1) | 🔶 | Density/coverage of the feature. |
| `HeightVarianceAmplitude` (0–128) | 🔶 | How much instance heights vary. |
| `HeightVarianceFrequency` (0–1000) | 🔶 | How rapidly that height variation changes across the world. |
| `HeightOffset` / `Offset` | 🔶 | Vertical placement + reference frame. |
| `Active`, `Subtract`, `MaximumLOD`, `VoxelType`, `SmoothRadius`, `SeedOffset`, `TileBlendMeters` | 🔶/✅ | Same meanings as in §3b. |

---

## 6. Caves — `TkNoiseCaveData`

✅ One cave system, `Underground`, with two sub-parts, each a feature block (§5):

- `Mouth` — the cave entrances at the surface.
- `Tunnel` — the underground passages.

Both are carved (subtractive). Depth/extent is bounded by the root `MinimumCaveDepth`,
`MaximumSeaLevelCaveDepth`, and `CaveRoofSmoothingDist`.

---

## 7. SuperFormula & SuperPrimitive shapes

### SuperFormula (`TkNoiseSuperFormulaData`) ✅ math, 🔶 usage
The **Gielis superformula** — a polar equation that produces an enormous variety of
symmetric organic shapes (stars, flowers, gems, blobs) from four numbers. NMS uses **two**
superformulas (`SuperFormula1`, `SuperFormula2`), one for each angular axis of a 3D shape,
to build the grid primitive.

| Field | What it does |
|---|---|
| `Form_m` (0.099–9.999) | **Symmetry / number of lobes.** Integer-ish m → m-fold symmetry (m=5 → 5-pointed star, m=6 → hexagonal/snowflake). |
| `Form_n1` (0–99.9) | Overall "inflation"/roundness. Low n1 → spiky; high n1 → puffy. |
| `Form_n2` (−49.5–100.5) | Shapes the lobes (pinch/bulge), in concert with n3. |
| `Form_n3` (−49.5–100.5) | Same family as n2; n2≠n3 makes lobes asymmetric. |

> The app's SuperFormula Playground tab renders these live in 3D so you can dial in a
> shape, then import its Min/Max into a grid layer.

### SuperPrimitive (`TkNoiseSuperPrimitiveData`) 🔶
A **rounded-box / capsule-family** primitive defined by a size box plus corner rounding —
think a parametric "squircle solid." Used when `NoiseGridType = SuperPrimitive`/`SuperPrimitiveRandom`.

| Field | What it does |
|---|---|
| `Width` / `Height` / `Depth` (0.099–1) | Box dimensions. |
| `Thickness` (0.099–1) | Shell/solidity (hollow → solid). |
| `CornerRadiusXY` / `CornerRadiusZ` (0–1) | Edge rounding in the horizontal plane and vertically. |
| `BottomRadiusOffset` (0–1) | Extra rounding/taper at the bottom (e.g. teardrop/pylon bases). |

---

## 8. Enum reference

- **Voxel / material types** (`BuildingVoxelType`, `ResourceVoxelType`, per-layer `VoxelType`):
  `Base`, `Rock`, `Mountain`, `Sand`, `Cave`, `Substance_1/2/3`, `RandomRock`,
  `RandomRockOrSubstance`. 🔶 Controls which texture/material set the affected voxels use.
- **Offset reference** (`OffsetType`): `Base`, `All`, `Zero`, `SeaLevel` — what a
  `HeightOffset` is measured relative to. 🔶
- **WaterFade**: `None`, `Above`, `Below` — whether a layer fades out above or below the
  water line. 🔶
- **DebugNoiseType**: `Uber` (real), `Plane`, `Check`, `Sine` (debug). ❓
- **FeatureType**: `Tube`, `Blob`. 🔶
- **NoiseGridType**: the grid primitive list in §4. ✅

---

## 9. Going deeper: decompiling NMS yourself

You don't actually need a disassembler to understand most of this, and here's the order I'd
work in:

1. **The data files (you're already here).** `VoxelGeneratorSettings.MBIN` lives inside the
   packed archives at
   `…/No Man's Sky.app/Contents/Resources/GAMEDATA/MACOSBANKS/*.pak` (these are **PSARC**
   archives). The flow is: unpack the `.pak` → get `.MBIN` → convert `.MBIN` ↔ readable
   `.EXML/.MXML` with **MBINCompiler**. *(You already maintain a macOS fork of MBINCompiler —
   that's exactly the tool, and it's how the files this app edits were produced.)*
   - Easiest all-in-one: **AMUMSS** (the community mod-builder) wraps unpacking +
     MBINCompiler + repacking with Lua scripts.

2. **The algorithm — read the author, don't disassemble.** ✅ The terrain noise is published.
   Giliam de Carpentier's site documents the exact erosion/warp terms that the `NoiseData`
   fields map onto, and the GDC 2017 talk covers the world-gen architecture. This is far more
   useful than staring at assembly:
   - de Carpentier, *Procedural & noise extensions*: <https://www.decarpentier.nl/scape-procedural-extensions>
   - GDC 2017, *Continuous World Generation in No Man's Sky*: <https://www.gdcvault.com/play/1024265/Continuous-World-Generation-in-No>

3. **Live tweaking (fastest feedback loop).** ✅ The Step Mods tutorial walks through using
   **Cheat Engine** to find the active terrain floats in memory and edit them while flying —
   change a value, dive to the surface, see the effect, no rebuild. (Cheat Engine is Windows;
   on a Mac you'd do this in a Windows VM or on a PC copy.)

4. **Actually disassembling the executable (last resort).** The macOS binary is a 201 MB
   **universal Mach-O** (`x86_64` + `arm64`) at `…/Contents/MacOS/No Man's Sky`. If you want
   the real generator code:
   - **Ghidra** (free, from the NSA) or **IDA Pro** / **Binary Ninja** / **Hopper** (Hopper is
     Mac-native and the gentlest start). Load the binary, let it auto-analyze, and search for
     the `TkVoxelGeneratorData`/`TkNoiseUberData` field strings — MBIN structs keep their
     names, so string search lands you near the (de)serialization and often near the consumers.
   - Thin the universal binary first for sanity:
     `lipo "No Man's Sky" -thin arm64 -output nms_arm64` (or `-thin x86_64`).
   - Reality check: this is a big, optimized C++ binary with no symbols for the hot math. The
     community has mostly *not* gone this route for terrain — steps 2 + 3 got them the
     knowledge on this page. Decompiling is worth it only for something the published material
     and live-editing can't answer.

> [!WARNING]
> Stay on the data/modding side. Don't redistribute extracted game assets or the binary —
> keep your work to your own local copy and shareable *mod files* (the `.MBIN`/`.pak` you
> author), which is how the NMS modding community operates.

---

## Sources

- [Step Mods — NoMansSky Terrain Generation tutorial](https://stepmodifications.org/wiki/NoMansSky:Tutorials/Terrain_Generation) (layer roster, Min/Max behavior, Cheat Engine workflow)
- [No Man's Sky Modding Wiki — Terrain Generation](https://nmsmodding.fandom.com/wiki/Terrain_Generation)
- [Giliam de Carpentier — procedural noise / terrain erosion extensions](https://www.decarpentier.nl/scape-procedural-extensions) (the "uber noise" math behind `NoiseData`)
- [GDC Vault — Continuous World Generation in No Man's Sky (2017)](https://www.gdcvault.com/play/1024265/Continuous-World-Generation-in-No)
- Field names, value ranges, and structure: the 31 bundled terrain files in this repo + this app's `ModelsOfXML/` Swift models.

*This document is community-reconstructed and partly speculative — corrections welcome as
in-game testing confirms or refutes the 🔶/❓ entries.*
