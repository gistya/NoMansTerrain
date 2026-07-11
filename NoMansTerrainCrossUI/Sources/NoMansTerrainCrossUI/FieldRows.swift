import Foundation
import NoMansTerrainCore
import SwiftCrossUI

// Reusable Min/Max field rows for the cross-platform editor. Built from only the
// SwiftCrossUI primitives proven to work (Text / Button / Slider) so there's no dependency
// on Toggle/Picker/Stepper availability: numbers use sliders with live readouts, bools use
// on/off buttons, enums use cycle buttons. Each row edits a Min and a Max binding.

private func fmt(_ v: Double) -> String { String(format: "%.2f", v) }

/// Slider range widened to include the current values, so a value loaded outside the
/// documented range is never silently clamped by the control.
private func widened(_ range: ClosedRange<Double>, _ a: Double, _ b: Double) -> ClosedRange<Double> {
    let lo = Swift.min(range.lowerBound, a, b)
    let hi = Swift.max(range.upperBound, a, b)
    return lo < hi ? lo...hi : lo...(lo + 1)
}

struct MinMaxDoubleRow: View {
    let label: String
    @Binding var minValue: Double
    @Binding var maxValue: Double
    let range: ClosedRange<Double>

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(label)   min \(fmt(minValue))   ·   max \(fmt(maxValue))")
            HStack(spacing: 6) {
                Text("min").frame(width: 34)
                Slider(value: clampedBinding($minValue, below: maxValue), in: widened(range, minValue, maxValue))
            }
            HStack(spacing: 6) {
                Text("max").frame(width: 34)
                Slider(value: clampedBinding($maxValue, above: minValue), in: widened(range, minValue, maxValue))
            }
        }
    }

    /// Keeps min ≤ max: editing min pulls max up if needed.
    private func clampedBinding(_ b: Binding<Double>, below other: Double) -> Binding<Double> {
        Binding(get: { b.wrappedValue }, set: { v in b.wrappedValue = v; if v > maxValue { maxValue = v } })
    }
    private func clampedBinding(_ b: Binding<Double>, above other: Double) -> Binding<Double> {
        Binding(get: { b.wrappedValue }, set: { v in b.wrappedValue = v; if v < minValue { minValue = v } })
    }
}

struct MinMaxIntRow: View {
    let label: String
    @Binding var minValue: Int
    @Binding var maxValue: Int
    let range: ClosedRange<Int>

    var body: some View {
        let dRange = Double(Swift.min(range.lowerBound, minValue, maxValue))...Double(Swift.max(range.upperBound, minValue, maxValue) + 1)
        return VStack(alignment: .leading, spacing: 1) {
            Text("\(label)   min \(minValue)   ·   max \(maxValue)")
            HStack(spacing: 6) {
                Text("min").frame(width: 34)
                Slider(value: intBinding($minValue, coupleUp: true), in: dRange)
            }
            HStack(spacing: 6) {
                Text("max").frame(width: 34)
                Slider(value: intBinding($maxValue, coupleUp: false), in: dRange)
            }
        }
    }

    private func intBinding(_ b: Binding<Int>, coupleUp: Bool) -> Binding<Double> {
        Binding(
            get: { Double(b.wrappedValue) },
            set: { d in
                let v = Int(d.rounded())
                b.wrappedValue = v
                if coupleUp, v > maxValue { maxValue = v }
                if !coupleUp, v < minValue { minValue = v }
            }
        )
    }
}

struct MinMaxBoolRow: View {
    let label: String
    @Binding var minValue: Bool
    @Binding var maxValue: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(label).frame(width: 150)
            Button("min: \(minValue ? "on" : "off")") {
                minValue.toggle()
                if minValue, !maxValue { maxValue = true }
            }
            Button("max: \(maxValue ? "on" : "off")") {
                maxValue.toggle()
                if !maxValue, minValue { minValue = false }
            }
        }
    }
}

/// Enum row: a cycle button per side (tap advances to the next case), constrained like the
/// macOS `MinMaxEnumField`. Kept min ≤ max by case order.
struct MinMaxEnumRow<T>: View where T: CaseIterable & RawRepresentable & Equatable, T.RawValue == String, T.AllCases: RandomAccessCollection {
    let label: String
    @Binding var minValue: T
    @Binding var maxValue: T

    private var cases: [T] { Array(T.allCases) }

    var body: some View {
        HStack(spacing: 8) {
            Text(label).frame(width: 150)
            Button("min: \(minValue.rawValue)") {
                minValue = next(minValue)
                if index(minValue) > index(maxValue) { maxValue = minValue }
            }
            Button("max: \(maxValue.rawValue)") {
                maxValue = next(maxValue)
                if index(maxValue) < index(minValue) { minValue = maxValue }
            }
        }
    }

    private func index(_ v: T) -> Int { cases.firstIndex(of: v) ?? 0 }
    private func next(_ v: T) -> T {
        guard !cases.isEmpty else { return v }
        return cases[(index(v) + 1) % cases.count]
    }
}

/// Base-seed row: toggle NONE per side, plus a "randomize" that assigns a fresh integer
/// seed. Precise numeric entry is intentionally omitted (seeds change rarely).
struct MinMaxSeedRow: View {
    let label: String
    @Binding var minSeed: BaseSeed
    @Binding var maxSeed: BaseSeed

    var body: some View {
        HStack(spacing: 8) {
            Text(label).frame(width: 120)
            Button("min: \(minSeed.seed.map(String.init) ?? "NONE")") { minSeed = toggle(minSeed) }
            Button("max: \(maxSeed.seed.map(String.init) ?? "NONE")") { maxSeed = toggle(maxSeed) }
            Button("🎲") {
                let v = Int.random(in: 0...1_000_000)
                minSeed = BaseSeed(seed: v)
                maxSeed = BaseSeed(seed: v)
            }
        }
    }

    private func toggle(_ s: BaseSeed) -> BaseSeed {
        s.seed == nil ? BaseSeed(seed: 0) : BaseSeed(seed: nil)
    }
}
