import NoMansTerrainCore
import SwiftCrossUI

// ⚠️ REJECTED EXPERIMENT (kept for reference). The `Shape`/`Path` rendering IS native per
// backend (NSBezierPath/WinUI Path/Cairo), but a Shape is single-fill, so a multi-colored
// depth-ordered 3D histogram needs ~1 Shape per bar face (≈res²×3 ≈ 970+ views) stacked in
// painter order. Result on macOS: (1) nothing rendered — each Shape is laid out as its own
// view and doesn't fill the shared container, so the absolute-coordinate faces collapse;
// (2) sliders unusably slow — SwiftCrossUI reconciling ~970 shape-views per tick. Per-color
// grouping (≤17 shapes) would be fast but breaks cross-color occlusion. Conclusion: use the
// native-embed (`RegionHistogramView` NSView / Win2D) immediate-mode draw instead.
//
/// Region histogram drawn with SwiftCrossUI `Shape`/`Path` (see warning above).
struct RegionHistogramShapeView: View {
    var field: RegionField

    var body: some View {
        ZStack {
            ForEach(faces(), id: \.id) { face in
                FaceShape(corners: face.corners).fill(face.color)
            }
        }
    }

    private struct Face: Identifiable {
        let id: Int
        let corners: [SIMD2<Double>] // fractions in [0,1], y-down
        let color: Color
    }

    private func faces() -> [Face] {
        let res = field.resolution
        guard res > 1 else { return [] }
        let n = Double(res - 1)
        let spanX = n
        let spanY = n * 0.5 + 2.0
        let margin = 0.05

        // Isometric projection (u = 1), then normalized into [0,1] with a margin.
        func project(_ i: Double, _ j: Double, _ h: Double) -> SIMD2<Double> {
            let px = (i - j) * 0.5
            let py = (i + j) * 0.25 - h * 2.0
            let fx = (px + spanX / 2) / spanX
            let fy = (py + 2.0) / spanY
            return SIMD2(margin + (1 - 2 * margin) * fx, margin + (1 - 2 * margin) * fy)
        }

        let palette = RegionHistogramRaster.defaultPalette
        func color(_ index: Int, _ f: Double) -> Color {
            let c = index >= 0 ? palette[index % palette.count] : (60, 64, 78)
            return Color(red: Double(c.0) * f / 255, green: Double(c.1) * f / 255, blue: Double(c.2) * f / 255)
        }

        var order: [(Int, Int)] = []
        order.reserveCapacity(res * res)
        for j in 0..<res { for i in 0..<res { order.append((i, j)) } }
        order.sort { ($0.0 + $0.1) < ($1.0 + $1.1) }

        var result: [Face] = []
        result.reserveCapacity(res * res * 3)
        var id = 0
        for (i, j) in order {
            let cell = field.cell(i, j)
            let h = max(cell.height, 0.02)
            let di = Double(i), dj = Double(j)
            let topBright = 0.6 + 0.4 * min(max(cell.height, 0), 1)

            // Right (east) face.
            result.append(Face(id: id, corners: [
                project(di + 1, dj, h), project(di + 1, dj + 1, h),
                project(di + 1, dj + 1, 0), project(di + 1, dj, 0),
            ], color: color(cell.colorIndex, 0.74))); id += 1
            // Left (south) face.
            result.append(Face(id: id, corners: [
                project(di, dj + 1, h), project(di + 1, dj + 1, h),
                project(di + 1, dj + 1, 0), project(di, dj + 1, 0),
            ], color: color(cell.colorIndex, 0.55))); id += 1
            // Top face.
            result.append(Face(id: id, corners: [
                project(di, dj, h), project(di + 1, dj, h),
                project(di + 1, dj + 1, h), project(di, dj + 1, h),
            ], color: color(cell.colorIndex, topBright))); id += 1
        }
        return result
    }
}

/// A single quad face. Corners are fractions of the layout bounds (y-down).
private struct FaceShape: Shape {
    let corners: [SIMD2<Double>]

    func path(in bounds: Path.Rect) -> Path {
        let pts = corners.map {
            SIMD2(bounds.x + $0.x * bounds.width, bounds.y + $0.y * bounds.height)
        }
        var path = Path().move(to: pts[0])
        for p in pts.dropFirst() { path = path.addLine(to: p) }
        return path
    }
}
