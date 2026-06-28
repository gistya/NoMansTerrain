import Testing
@testable import NoMansTerrainCore

private func demoLayers() -> [RegionLayerState] {
    let layers = (0..<6).map { i in
        RegionLayerState(id: "L\(i)", name: "L\(i)", colorIndex: i, active: true,
                         ratio: 0.5, scale: 6, gain: 2, hasGain: true, elevation: 0)
    }
    return RegionFieldSampler.autoTier(layers)
}

@Test func histogramRasterHasCorrectSizeAndDeterminism() {
    let field = RegionFieldSampler.sample(layers: demoLayers(), resolution: 24)
    let a = RegionHistogramRaster.render(field: field, width: 200, height: 160)
    let b = RegionHistogramRaster.render(field: field, width: 200, height: 160)

    #expect(a.width == 200 && a.height == 160)
    #expect(a.bytes.count == 200 * 160 * 4)
    #expect(a.bytes == b.bytes, "rasterizer must be deterministic")
}

@Test func histogramRasterDrawsBars() {
    let field = RegionFieldSampler.sample(layers: demoLayers(), resolution: 24)
    let bg: (UInt8, UInt8, UInt8) = (18, 20, 28)
    let raster = RegionHistogramRaster.render(field: field, width: 200, height: 160, background: bg)

    // Some pixels must differ from the background (i.e. bars were actually drawn).
    var nonBackground = 0
    var p = 0
    while p < raster.bytes.count {
        if raster.bytes[p] != bg.0 || raster.bytes[p + 1] != bg.1 || raster.bytes[p + 2] != bg.2 {
            nonBackground += 1
        }
        p += 4
    }
    #expect(nonBackground > 500, "expected the isometric bars to cover a meaningful area")
}
