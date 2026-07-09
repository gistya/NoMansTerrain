import Foundation

/// A plain RGBA pixel buffer (row-major, 4 bytes/pixel). UI-framework-agnostic so the core
/// can render the region preview without depending on SwiftUI/SwiftCrossUI/ImageFormats —
/// the host wraps `bytes` into whatever image type its toolkit needs.
public struct RGBARaster: Sendable {
    public let width: Int
    public let height: Int
    public let bytes: [UInt8]
}

/// Software rasterizer for the region field. The macOS app draws the histogram with a
/// SwiftUI `Canvas`; on cross-platform (SwiftCrossUI) backends there is no Canvas, so we
/// rasterize to an `RGBARaster` here and the host shows it as an image. Same field, same
/// model, one renderer — fully cross-platform and testable.
public enum RegionHistogramRaster {
    /// RGB palette (parallels the SwiftUI `RegionPalette`) so colors match across platforms.
    public static let defaultPalette: [(UInt8, UInt8, UInt8)] = [
        (228, 60, 50), (235, 140, 30), (235, 205, 40), (70, 190, 90),
        (60, 200, 160), (40, 180, 180), (60, 200, 230), (60, 120, 230),
        (95, 90, 200), (150, 80, 200), (225, 90, 160), (160, 110, 70),
        (150, 200, 60), (225, 130, 175), (80, 180, 225), (200, 110, 60), (130, 220, 150),
    ]

    /// Renders the field as a colored isometric 3D bar chart (matches the macOS SwiftUI
    /// histogram): each surface cell is a bar at its layer's elevation tier, colored by
    /// layer, with shaded side faces. The projection is fit + centered to the canvas so it
    /// never crops. Drawn back-to-front (painter's algorithm).
    public static func render(
        field: RegionField,
        width: Int,
        height: Int,
        palette: [(UInt8, UInt8, UInt8)] = defaultPalette,
        background: (UInt8, UInt8, UInt8) = (18, 20, 28)
    ) -> RGBARaster {
        var px = [UInt8](repeating: 255, count: max(width, 1) * max(height, 1) * 4)
        for i in 0..<(width * height) {
            px[i * 4] = background.0; px[i * 4 + 1] = background.1; px[i * 4 + 2] = background.2
        }
        let res = field.resolution
        guard res > 1, width > 0, height > 0 else {
            return RGBARaster(width: width, height: height, bytes: px)
        }

        // Fit the isometric footprint (base diamond + bar headroom) inside the canvas.
        let n = Double(res - 1)
        let u = min(Double(width) / n, Double(height) / (n * 0.5 + 2.0)) * 0.9
        let tileW = u, tileH = u * 0.5, heightScale = u * 2.0
        let totalH = n * 0.5 * u + heightScale
        let ox = Double(width) / 2
        let oy = (Double(height) - totalH) / 2 + heightScale

        func project(_ i: Double, _ j: Double, _ h: Double) -> (Double, Double) {
            (ox + (i - j) * tileW / 2, oy + (i + j) * tileH / 2 - h * heightScale)
        }

        // Painter's order: back (small i+j) first.
        var order: [(Int, Int)] = []
        order.reserveCapacity(res * res)
        for j in 0..<res { for i in 0..<res { order.append((i, j)) } }
        order.sort { ($0.0 + $0.1) < ($1.0 + $1.1) }

        for (i, j) in order {
            let cell = field.cell(i, j)
            let base = cell.colorIndex >= 0 ? palette[cell.colorIndex % palette.count] : (60, 64, 78)
            let h = max(cell.height, 0.02)
            let di = Double(i), dj = Double(j)

            // Right (east) face — medium shade.
            fill([project(di + 1, dj, h), project(di + 1, dj + 1, h),
                  project(di + 1, dj + 1, 0), project(di + 1, dj, 0)],
                 shade(base, 0.74), &px, width, height)
            // Left (south) face — darkest.
            fill([project(di, dj + 1, h), project(di + 1, dj + 1, h),
                  project(di + 1, dj + 1, 0), project(di, dj + 1, 0)],
                 shade(base, 0.55), &px, width, height)
            // Top face — full color, brightened by tier height.
            fill([project(di, dj, h), project(di + 1, dj, h),
                  project(di + 1, dj + 1, h), project(di, dj + 1, h)],
                 shade(base, 0.6 + 0.4 * min(max(cell.height, 0), 1)), &px, width, height)
        }
        return RGBARaster(width: width, height: height, bytes: px)
    }

    // MARK: - Software polygon fill

    /// Scanline-fills a convex polygon (the bar faces are quads) into the RGBA buffer.
    private static func fill(
        _ pts: [(Double, Double)],
        _ color: (UInt8, UInt8, UInt8),
        _ px: inout [UInt8],
        _ width: Int,
        _ height: Int
    ) {
        var minY = Int.max, maxY = Int.min
        for p in pts {
            minY = Swift.min(minY, Int(p.1.rounded(.down)))
            maxY = Swift.max(maxY, Int(p.1.rounded(.up)))
        }
        minY = Swift.max(minY, 0); maxY = Swift.min(maxY, height - 1)
        if minY > maxY { return }
        let m = pts.count
        for y in minY...maxY {
            let yc = Double(y) + 0.5
            var xs: [Double] = []
            for k in 0..<m {
                let (x1, y1) = pts[k]
                let (x2, y2) = pts[(k + 1) % m]
                if (y1 <= yc && y2 > yc) || (y2 <= yc && y1 > yc) {
                    xs.append(x1 + (yc - y1) / (y2 - y1) * (x2 - x1))
                }
            }
            guard xs.count >= 2 else { continue }
            xs.sort()
            var k = 0
            while k + 1 < xs.count {
                let lo = Swift.max(0, Int(xs[k].rounded()))
                let hi = Swift.min(width - 1, Int(xs[k + 1].rounded()))
                if lo <= hi {
                    let row = y * width
                    for x in lo...hi {
                        let o = (row + x) * 4
                        px[o] = color.0; px[o + 1] = color.1; px[o + 2] = color.2; px[o + 3] = 255
                    }
                }
                k += 2
            }
        }
    }

    private static func shade(_ c: (UInt8, UInt8, UInt8), _ f: Double) -> (UInt8, UInt8, UInt8) {
        (clampByte(Double(c.0) * f), clampByte(Double(c.1) * f), clampByte(Double(c.2) * f))
    }

    private static func clampByte(_ v: Double) -> UInt8 {
        UInt8(Swift.min(255, Swift.max(0, v)))
    }
}
