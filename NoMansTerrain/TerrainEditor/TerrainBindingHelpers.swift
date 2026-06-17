import SwiftUI

enum TerrainEnumOptions {
    static func sortedCases<T: CaseIterable & RawRepresentable>() -> [T]
    where T.RawValue == String, T.AllCases: RandomAccessCollection {
        Array(T.allCases).sorted { $0.rawValue < $1.rawValue }
    }
}

enum TerrainEditableRanges {
    static func doubleRange(
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

extension Binding {
    /// Read-modify-write for value-type bindings so nested field edits propagate to the source.
    @MainActor
    func nested<Field>(_ keyPath: WritableKeyPath<Value, Field>) -> Binding<Field> {
        Binding<Field>(
            get: { wrappedValue[keyPath: keyPath] },
            set: { newValue in
                var copy = wrappedValue
                copy[keyPath: keyPath] = newValue
                wrappedValue = copy
            }
        )
    }
}

@MainActor
func mutateValue<Value>(_ binding: Binding<Value>, _ body: (inout Value) -> Void) {
    var copy = binding.wrappedValue
    body(&copy)
    binding.wrappedValue = copy
}

@MainActor
func mutatePair<Value>(
    _ min: Binding<Value>,
    _ max: Binding<Value>,
    _ body: (inout Value, inout Value) -> Void
) {
    var minCopy = min.wrappedValue
    var maxCopy = max.wrappedValue
    body(&minCopy, &maxCopy)
    min.wrappedValue = minCopy
    max.wrappedValue = maxCopy
}