import NoMansTerrainCore
import SwiftCrossUI

// The region histogram is a graphics-heavy, frequently-redrawn view. The portable
// "rasterize to an RGBA Image" path is too slow to scrub interactively, so we embed a
// *native* drawing surface per platform via SwiftCrossUI's backend representables.
//
//   macOS  → NSViewRepresentable + Core Graphics  (implemented & fast — the reference)
//   Windows → WinUIElementRepresentable + Win2D/Direct3D  (TODO: needs a Windows box)
//   Linux/other → RGBA image fallback (works, slower)

#if canImport(AppKitBackend)
import AppKit
import AppKitBackend

/// macOS native histogram: embeds an `NSView` that draws the isometric bars with Core
/// Graphics. Only this view repaints on change (no per-frame bitmap upload), so slider
/// scrubbing stays smooth.
struct RegionHistogramView: NSViewRepresentable {
    var field: RegionField

    func makeNSView(context: Context) -> RegionHistogramNSView {
        let view = RegionHistogramNSView()
        view.field = field
        return view
    }

    func updateNSView(_ nsView: RegionHistogramNSView, context: Context) {
        nsView.field = field
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: RegionHistogramNSView, context: Context) -> ViewSize {
        ViewSize(360, 360)
    }
}

final class RegionHistogramNSView: NSView {
    var field: RegionField? { didSet { needsDisplay = true } }
    override var isFlipped: Bool { true } // top-left origin, y-down (matches the projection)

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }
    required init?(coder: NSCoder) { super.init(coder: coder) }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = Double(bounds.width), h = Double(bounds.height)
        ctx.setFillColor(CGColor(red: 18 / 255, green: 20 / 255, blue: 28 / 255, alpha: 1))
        ctx.fill(bounds)
        guard let field, field.resolution > 1, w > 0, h > 0 else { return }

        let res = field.resolution
        let n = Double(res - 1)
        let u = min(w / n, h / (n * 0.5 + 2.0)) * 0.9
        let tileW = u, tileH = u * 0.5, heightScale = u * 2.0
        let totalH = n * 0.5 * u + heightScale
        let ox = w / 2
        let oy = (h - totalH) / 2 + heightScale

        func project(_ i: Double, _ j: Double, _ z: Double) -> CGPoint {
            CGPoint(x: ox + (i - j) * tileW / 2, y: oy + (i + j) * tileH / 2 - z * heightScale)
        }
        func fillQuad(_ pts: [CGPoint], _ c: (UInt8, UInt8, UInt8), _ f: Double) {
            ctx.setFillColor(CGColor(
                red: CGFloat(Double(c.0) * f / 255),
                green: CGFloat(Double(c.1) * f / 255),
                blue: CGFloat(Double(c.2) * f / 255), alpha: 1))
            ctx.beginPath()
            ctx.move(to: pts[0])
            for p in pts.dropFirst() { ctx.addLine(to: p) }
            ctx.closePath()
            ctx.fillPath()
        }

        let palette = RegionHistogramRaster.defaultPalette
        var order: [(Int, Int)] = []
        for j in 0..<res { for i in 0..<res { order.append((i, j)) } }
        order.sort { ($0.0 + $0.1) < ($1.0 + $1.1) }

        for (i, j) in order {
            let cell = field.cell(i, j)
            let base = cell.colorIndex >= 0 ? palette[cell.colorIndex % palette.count] : (60, 64, 78)
            let z = max(cell.height, 0.02)
            let di = Double(i), dj = Double(j)
            fillQuad([project(di + 1, dj, z), project(di + 1, dj + 1, z),
                      project(di + 1, dj + 1, 0), project(di + 1, dj, 0)], base, 0.74)        // right
            fillQuad([project(di, dj + 1, z), project(di + 1, dj + 1, z),
                      project(di + 1, dj + 1, 0), project(di, dj + 1, 0)], base, 0.55)        // left
            fillQuad([project(di, dj, z), project(di + 1, dj, z),
                      project(di + 1, dj + 1, z), project(di, dj + 1, z)],
                     base, 0.6 + 0.4 * min(max(cell.height, 0), 1))                            // top
        }
    }
}

#else
import ImageFormats

/// Portable fallback (Linux/Gtk now; Windows until a Win2D `WinUIElementRepresentable`
/// lands): software-rasterized RGBA image. Correct but slow to scrub — see the macOS
/// implementation above for the native pattern to mirror.
struct RegionHistogramView: View {
    var field: RegionField

    var body: some View {
        let raster = RegionHistogramRaster.render(field: field, width: 360, height: 360)
        return Image(ImageFormats.Image<RGBA>(width: raster.width, height: raster.height, bytes: raster.bytes))
            .resizable()
    }
}
#endif
