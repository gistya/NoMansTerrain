import SwiftUI

struct SectionActionBar<Value>: View {
    @Binding var minValue: Value
    @Binding var maxValue: Value
    let applyGlobalMin: (inout Value) -> Void
    let applyGlobalMax: (inout Value) -> Void
    let randomize: (inout Value, inout Value) -> Void

    var body: some View {
        HStack {
            Button("Lowest Mins", systemImage: "arrow.down.to.line") {
                mutateValue($minValue, applyGlobalMin)
            }
            Button("Highest Maxes", systemImage: "arrow.up.to.line") {
                mutateValue($maxValue, applyGlobalMax)
            }
            Button("Randomize", systemImage: "dice") {
                mutatePair($minValue, $maxValue, randomize)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .labelStyle(.titleAndIcon)
    }
}

/// Min/max double editor.
///
/// Sliders drive **local** `@State` while dragging and only write back to the
/// (potentially huge, `@Observable`) model bindings when the drag ends. That keeps
/// a slider drag from copying the entire terrain struct and rebuilding the whole
/// form on every frame. Text fields commit on return/focus-loss (low frequency),
/// so they write through immediately.
struct MinMaxDoubleField: View {
    let label: String
    @Binding var minValue: Double
    @Binding var maxValue: Double
    let range: ClosedRange<Double>

    @State private var localMin = 0.0
    @State private var localMax = 0.0

    /// Display range widened to include the current values so a value loaded from
    /// disk outside the documented range is never silently clamped.
    private var effectiveRange: ClosedRange<Double> {
        let lo = Swift.min(range.lowerBound, localMin, localMax)
        let hi = Swift.max(range.upperBound, localMin, localMax)
        return lo <= hi ? lo...hi : lo...lo
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
        .onAppear {
            localMin = minValue
            localMax = maxValue
        }
        .onDisappear { commit() }
        .onChange(of: minValue) { _, newValue in if newValue != localMin { localMin = newValue } }
        .onChange(of: maxValue) { _, newValue in if newValue != localMax { localMax = newValue } }
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
                onEditingChanged: { editing in if !editing { commit() } }
            )
            TextField(title, value: textBinding(isMinColumn: isMinColumn), format: .number.precision(.fractionLength(3)))
                .textFieldStyle(.roundedBorder)
                .writingToolsBehavior(.disabled)
        }
        .frame(maxWidth: .infinity)
    }

    /// Live slider binding: updates local state only (and keeps min ≤ max visually),
    /// deferring the model write to `commit()` on release.
    private func sliderBinding(isMinColumn: Bool) -> Binding<Double> {
        Binding(
            get: { isMinColumn ? localMin : localMax },
            set: { newValue in
                if isMinColumn {
                    localMin = newValue
                    if localMin > localMax { localMax = localMin }
                } else {
                    localMax = newValue
                    if localMax < localMin { localMin = localMax }
                }
            }
        )
    }

    /// Text field binding: commits to the model immediately on edit (low frequency).
    private func textBinding(isMinColumn: Bool) -> Binding<Double> {
        Binding(
            get: { isMinColumn ? localMin : localMax },
            set: { newValue in
                if isMinColumn {
                    localMin = newValue
                    if localMin > localMax { localMax = localMin }
                } else {
                    localMax = newValue
                    if localMax < localMin { localMin = localMax }
                }
                commit()
            }
        )
    }

    private func commit() {
        if minValue != localMin { minValue = localMin }
        if maxValue != localMax { maxValue = localMax }
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