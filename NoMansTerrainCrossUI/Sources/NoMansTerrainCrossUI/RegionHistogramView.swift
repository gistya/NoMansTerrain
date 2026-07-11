import NoMansTerrainCore
import SwiftCrossUI

// The region histogram is a graphics-heavy, frequently-redrawn view embedded as a *native*
// drawing surface per platform via SwiftCrossUI's backend representables:
//   macOS  → NSViewRepresentable + Core Graphics  (implemented & fast — the reference)
//   Windows → WinUIElementRepresentable + Win2D/Direct3D  (TODO: needs a Windows box)
//   Linux/other → RGBA image fallback (works, slower)
//
// ⚠️ SwiftCrossUI gotcha: representables only store the representable value at init —
// `updateNSView`/`updateWinUIElement` are called every render but with the ORIGINAL value
// (computeLayout never reassigns it). So a representable's stored props are FROZEN. We work
// around it by passing data through this reference box, whose contents the app refreshes
// each render; the (frozen) representable still holds the same box, so update reads fresh
// data. The Windows representable will need the identical pattern.

/// Reference holder so fresh field data reaches a frozen representable.
final class RegionFieldBox {
    var field: RegionField?
    init() {}
}

#if canImport(AppKitBackend)
import AppKit
import AppKitBackend

/// macOS native histogram: embeds an `NSView` that draws the isometric bars with Core
/// Graphics. Only this view repaints on change (no per-frame bitmap upload).
struct RegionHistogramView: NSViewRepresentable {
    let box: RegionFieldBox

    func makeNSView(context: Context) -> RegionHistogramNSView {
        let view = RegionHistogramNSView()
        view.field = box.field
        return view
    }

    func updateNSView(_ nsView: RegionHistogramNSView, context: Context) {
        nsView.field = box.field // box is shared/current even though `self` is frozen
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
                      project(di + 1, dj + 1, 0), project(di + 1, dj, 0)], base, 0.74)
            fillQuad([project(di, dj + 1, z), project(di + 1, dj + 1, z),
                      project(di + 1, dj + 1, 0), project(di, dj + 1, 0)], base, 0.55)
            fillQuad([project(di, dj, z), project(di + 1, dj, z),
                      project(di + 1, dj + 1, z), project(di, dj + 1, z)],
                     base, 0.6 + 0.4 * min(max(cell.height, 0), 1))
        }
    }
}

#else
import ImageFormats

/// Portable fallback (Linux now; Windows until a Win2D representable lands). A normal View,
/// so its body re-runs each render and stays current — but software-rasterized and slow.
struct RegionHistogramView: View {
    let box: RegionFieldBox

    @ViewBuilder
    var body: some View {
        if let field = box.field {
            let raster = RegionHistogramRaster.render(field: field, width: 360, height: 360)
            Image(ImageFormats.Image<RGBA>(width: raster.width, height: raster.height, bytes: raster.bytes))
                .resizable()
        } else {
            Color(red: 18 / 255, green: 20 / 255, blue: 28 / 255)
        }
    }
}
#endif
