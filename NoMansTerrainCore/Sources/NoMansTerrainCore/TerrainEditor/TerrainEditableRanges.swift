import Foundation

public enum TerrainEditableRanges {
    public static func doubleRange(
        aggregatedMin: Double,
        aggregatedMax: Double,
        currentMin: Double? = nil,
        currentMax: Double? = nil
    ) -> ClosedRange<Double> {
        var lower = Swift.min(aggregatedMin, aggregatedMax)
        var upper = Swift.max(aggregatedMin, aggregatedMax)
        if lower == upper {
            let padding = Swift.max(Swift.abs(lower) * 0.25, 1.0)
            lower -= padding
            upper += padding
        }
        if let currentMin { lower = Swift.min(lower, currentMin) }
        if let currentMax { upper = Swift.max(upper, currentMax) }
        return lower...upper
    }
}
