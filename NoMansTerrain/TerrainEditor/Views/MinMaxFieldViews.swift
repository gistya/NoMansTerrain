import SwiftUI

struct SectionActionBar<Value: ActivePreserving>: View {
    @Binding var minValue: Value
    @Binding var maxValue: Value
    let applyGlobalMin: (inout Value) -> Void
    let applyGlobalMax: (inout Value) -> Void
    let randomize: (inout Value, inout Value) -> Void

    /// When on, Set Min/Max and Randomize leave each layer's `active` flag untouched.
    @AppStorage("terrainLockActive") private var lockActive = false

    var body: some View {
        HStack {
            Button("Lowest Mins", systemImage: "arrow.down.to.line") {
                applyPreservingActive($minValue, applyGlobalMin)
            }
            Button("Highest Maxes", systemImage: "arrow.up.to.line") {
                applyPreservingActive($maxValue, applyGlobalMax)
            }
            Button("Randomize", systemImage: "dice") {
                let prevMin = minValue
                let prevMax = maxValue
                mutatePair($minValue, $maxValue, randomize)
                if lockActive {
                    minValue = minValue.preservingActive(from: prevMin)
                    maxValue = maxValue.preservingActive(from: prevMax)
                }
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .labelStyle(.titleAndIcon)
    }

    private func applyPreservingActive(_ binding: Binding<Value>, _ op: (inout Value) -> Void) {
        let previous = binding.wrappedValue
        mutateValue(binding, op)
        if lockActive {
            binding.wrappedValue = binding.wrappedValue.preservingActive(from: previous)
        }
    }
}

/// Min/max double editor.
///
/// Sliders show the **model value directly** except while actively dragging, when they
/// switch to a transient local value and only write back to the (potentially huge,
/// `@Observable`) model on release. That keeps a drag from copying the entire terrain
/// struct every frame, while still reflecting external changes (Lowest/Highest buttons,
/// randomize, tab switches) immediately. Text fields commit on return/focus-loss.
struct MinMaxDoubleField: View {
    let label: String
    @Binding var minValue: Double
    @Binding var maxValue: Double
    let range: ClosedRange<Double>

    /// Non-nil only while that column's slider is being dragged.
    @State private var dragMin: Double?
    @State private var dragMax: Double?

    /// Display range widened to include the current values so a value loaded from
    /// disk outside the documented range is never silently clamped.
    private var effectiveRange: ClosedRange<Double> {
        let lo = Swift.min(range.lowerBound, minValue, maxValue)
        let hi = Swift.max(range.upperBound, minValue, maxValue)
        return lo < hi ? lo...hi : lo...(lo + 1)
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text(label)
                .font(.subheadline.weight(.medium))

            HStack {
                valueColumn(title: "Min File", isMinColumn: true)
                valueColumn(title: "Max File", isMinColumn: false)
            }

            Text("Valid: \(range.lowerBound, format: .number.precision(.fractionLength(2))) – \(range.upperBound, format: .number.precision(.fractionLength(2)))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), min \(minValue), max \(maxValue)")
    }

    @ViewBuilder
    private func valueColumn(title: String, isMinColumn: Bool) -> some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Slider(
                value: sliderBinding(isMinColumn: isMinColumn),
                in: effectiveRange,
                onEditingChanged: { editing in
                    if editing {
                        if isMinColumn { dragMin = minValue } else { dragMax = maxValue }
                    } else {
                        if isMinColumn {
                            if let v = dragMin { setMin(v) }
                            dragMin = nil
                        } else {
                            if let v = dragMax { setMax(v) }
                            dragMax = nil
                        }
                    }
                }
            )
            TextField(title, value: textBinding(isMinColumn: isMinColumn), format: .number.precision(.fractionLength(3)))
                .textFieldStyle(.roundedBorder)
                .writingToolsBehavior(.disabled)
        }
        .frame(maxWidth: .infinity)
    }

    /// While dragging, reflects the transient local value; otherwise the model value
    /// (so external mutations show up immediately).
    private func sliderBinding(isMinColumn: Bool) -> Binding<Double> {
        Binding(
            get: { isMinColumn ? (dragMin ?? minValue) : (dragMax ?? maxValue) },
            set: { newValue in
                if isMinColumn { dragMin = newValue } else { dragMax = newValue }
            }
        )
    }

    /// Text field reads/writes the model directly (low frequency, commits on return).
    private func textBinding(isMinColumn: Bool) -> Binding<Double> {
        Binding(
            get: { isMinColumn ? minValue : maxValue },
            set: { newValue in
                if isMinColumn { setMin(newValue) } else { setMax(newValue) }
            }
        )
    }

    private func setMin(_ value: Double) {
        minValue = value
        if value > maxValue { maxValue = value }
    }

    private func setMax(_ value: Double) {
        maxValue = value
        if value < minValue { minValue = value }
    }
}

struct MinMaxIntField: View {
    let label: String
    @Binding var minValue: Int
    @Binding var maxValue: Int
    let range: ClosedRange<Int>

    /// Range used for the stepper/clamp. The incoming range can collapse to a single
    /// value (`n...n`) when the aggregated min/max are equal, which leaves a Stepper
    /// permanently disabled. Widen it (and include current values) so the control is
    /// always usable and never silently clamps a loaded value.
    private var effectiveRange: ClosedRange<Int> {
        let lo = Swift.min(range.lowerBound, range.upperBound, minValue, maxValue)
        let hi = Swift.max(range.lowerBound, range.upperBound, minValue, maxValue)
        return lo == hi ? lo...(hi + 1) : lo...hi
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text(label)
                .font(.subheadline.weight(.medium))

            HStack {
                intColumn(title: "Min File", value: $minValue, isMinColumn: true)
                intColumn(title: "Max File", value: $maxValue, isMinColumn: false)
            }

            Text("Valid: \(range.lowerBound) – \(range.upperBound)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), min \(minValue), max \(maxValue)")
    }

    @ViewBuilder
    private func intColumn(title: String, value: Binding<Int>, isMinColumn: Bool) -> some View {
        let bound = Binding(
            get: { value.wrappedValue },
            set: { newValue in
                let clamped = min(max(newValue, effectiveRange.lowerBound), effectiveRange.upperBound)
                value.wrappedValue = clamped
                if isMinColumn, clamped > maxValue { maxValue = clamped }
                if !isMinColumn, clamped < minValue { minValue = clamped }
            }
        )

        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                TextField(title, value: bound, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .writingToolsBehavior(.disabled)
                    .frame(maxWidth: .infinity)
#if os(iOS)
                    .keyboardType(.numbersAndPunctuation)
#endif
                Stepper(value: bound, in: effectiveRange) {
                    EmptyView()
                }
                .labelsHidden()
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct MinMaxBoolField: View {
    let label: String
    @Binding var minValue: Bool
    @Binding var maxValue: Bool

    var body: some View {
        VStack(alignment: .leading) {
            Text(label)
                .font(.subheadline.weight(.medium))
            HStack {
                Toggle("Min File", isOn: Binding(
                    get: { minValue },
                    set: { newValue in
                        minValue = newValue
                        if newValue, !maxValue { maxValue = true }
                    }
                ))
                Toggle("Max File", isOn: Binding(
                    get: { maxValue },
                    set: { newValue in
                        maxValue = newValue
                        if !newValue, minValue { minValue = false }
                    }
                ))
            }
        }
        .padding(.vertical, 4)
    }
}

struct MinMaxEnumField<T: Hashable & CaseIterable & RawRepresentable>: View
where T.RawValue == String, T.AllCases: RandomAccessCollection {
    let label: String
    @Binding var minValue: T
    @Binding var maxValue: T

    var body: some View {
        MinMaxEnumPicker(
            label: label,
            minValue: $minValue,
            maxValue: $maxValue,
            options: TerrainEnumOptions.sortedCases()
        )
    }
}

struct MinMaxEnumPicker<T: Hashable & CaseIterable & RawRepresentable>: View where T.RawValue == String, T.AllCases: RandomAccessCollection {
    let label: String
    @Binding var minValue: T
    @Binding var maxValue: T
    let options: [T]

    var body: some View {
        VStack(alignment: .leading) {
            Text(label)
                .font(.subheadline.weight(.medium))
            HStack {
                Picker("Min File", selection: Binding(
                    get: { minValue },
                    set: { newValue in
                        minValue = newValue
                        if index(of: newValue) > index(of: maxValue) { maxValue = newValue }
                    }
                )) {
                    ForEach(options, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)
                Picker("Max File", selection: Binding(
                    get: { maxValue },
                    set: { newValue in
                        maxValue = newValue
                        if index(of: newValue) < index(of: minValue) { minValue = newValue }
                    }
                )) {
                    ForEach(options, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .padding(.vertical, 4)
    }

    /// Position of a case within the displayed option order, used so the min/max
    /// coupling reflects the picker's order rather than alphabetical rawValue order.
    private func index(of value: T) -> Int {
        options.firstIndex(of: value) ?? 0
    }
}

struct MinMaxSeedField: View {
    let label: String
    @Binding var minSeed: BaseSeed
    @Binding var maxSeed: BaseSeed

    var body: some View {
        VStack(alignment: .leading) {
            Text(label)
                .font(.subheadline.weight(.medium))
            HStack {
                seedColumn(title: "Min File", seed: $minSeed, other: maxSeed, isMinColumn: true)
                seedColumn(title: "Max File", seed: $maxSeed, other: minSeed, isMinColumn: false)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func seedColumn(title: String, seed: Binding<BaseSeed>, other: BaseSeed, isMinColumn: Bool) -> some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Toggle("Use NONE", isOn: Binding(
                get: { seed.wrappedValue.seed == nil },
                set: { useNone in
                    if useNone {
                        seed.wrappedValue = BaseSeed(seed: nil)
                    } else {
                        seed.wrappedValue = BaseSeed(seed: other.seed ?? 0)
                    }
                }
            ))
            if seed.wrappedValue.seed != nil {
                TextField("Seed", value: Binding(
                    get: { seed.wrappedValue.seed ?? 0 },
                    set: { newValue in
                        seed.wrappedValue = BaseSeed(seed: newValue)
                        if isMinColumn, let otherSeed = other.seed, newValue > otherSeed {
                            maxSeed = BaseSeed(seed: newValue)
                        }
                        if !isMinColumn, let otherSeed = other.seed, newValue < otherSeed {
                            minSeed = BaseSeed(seed: newValue)
                        }
                    }
                ), format: .number)
                .textFieldStyle(.roundedBorder)
                .writingToolsBehavior(.disabled)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
