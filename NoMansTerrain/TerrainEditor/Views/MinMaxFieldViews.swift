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

struct MinMaxDoubleField: View {
    let label: String
    @Binding var minValue: Double
    @Binding var maxValue: Double
    let range: ClosedRange<Double>

    var body: some View {
        VStack(alignment: .leading) {
            Text(label)
                .font(.subheadline.weight(.medium))

            HStack {
                valueColumn(title: "Min File", value: $minValue, other: $maxValue, isMinColumn: true)
                valueColumn(title: "Max File", value: $maxValue, other: $minValue, isMinColumn: false)
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
    private func valueColumn(
        title: String,
        value: Binding<Double>,
        other: Binding<Double>,
        isMinColumn: Bool
    ) -> some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Slider(value: clampedBinding(value: value, other: other, isMinColumn: isMinColumn), in: range)
            TextField(title, value: value, format: .number.precision(.fractionLength(3)))
                .textFieldStyle(.roundedBorder)
                .writingToolsBehavior(.disabled)
                .onChange(of: value.wrappedValue) { _, newValue in
                    let clamped = min(max(newValue, range.lowerBound), range.upperBound)
                    if clamped != newValue { value.wrappedValue = clamped }
                    if isMinColumn, clamped > other.wrappedValue { other.wrappedValue = clamped }
                    if !isMinColumn, clamped < other.wrappedValue { other.wrappedValue = clamped }
                }
        }
        .frame(maxWidth: .infinity)
    }

    private func clampedBinding(
        value: Binding<Double>,
        other: Binding<Double>,
        isMinColumn: Bool
    ) -> Binding<Double> {
        Binding(
            get: { value.wrappedValue },
            set: { newValue in
                let clamped = min(max(newValue, range.lowerBound), range.upperBound)
                value.wrappedValue = clamped
                if isMinColumn, clamped > other.wrappedValue {
                    other.wrappedValue = clamped
                } else if !isMinColumn, clamped < other.wrappedValue {
                    other.wrappedValue = clamped
                }
            }
        )
    }
}

struct MinMaxIntField: View {
    let label: String
    @Binding var minValue: Int
    @Binding var maxValue: Int
    let range: ClosedRange<Int>

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
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Stepper(value: Binding(
                get: { value.wrappedValue },
                set: { newValue in
                    let clamped = min(max(newValue, range.lowerBound), range.upperBound)
                    value.wrappedValue = clamped
                    if isMinColumn, clamped > maxValue { maxValue = clamped }
                    if !isMinColumn, clamped < minValue { minValue = clamped }
                }
            ), in: range) {
                Text("\(value.wrappedValue)")
                    .monospacedDigit()
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
                        if newValue.rawValue > maxValue.rawValue { maxValue = newValue }
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
                        if newValue.rawValue < minValue.rawValue { minValue = newValue }
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