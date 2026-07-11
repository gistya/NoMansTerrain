import NoMansTerrainCore
import SwiftUI
import SwiftData
#if os(macOS)
import AppKit
#endif

/// Editor for a ``TerrainSettingsFolder``: a grid of all 31 game terrain slots that can
/// be filled by dragging library terrains in, auto-filling, or converting/saving slots,
/// then exported as a single `voxelgeneratorsettings.MXML`.
struct TerrainFolderGridView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var folder: TerrainSettingsFolder
    let catalog: TerrainLimitsCatalog

    private enum FillMode { case random, preset }

    @State private var isWorking = false
    @State private var workMessage = ""
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var exportURLs: [URL] = []
    @State private var showShareSheet = false

    /// When on, randomly-filled slots get every layer's LOD pinned to max instead of a
    /// random LOD (low LODs cause major in-game issues). Mirrors the editor's toggle.
    @AppStorage("terrainLockLODMax") private var lockLODMax = false

    /// When on, randomly-filled slots also get a balanced "smart region mix" applied so
    /// every layer gets a good smattering of coverage. Shared with the random-set export.
    @AppStorage("terrainSmartMixOnRandom") private var smartMixOnRandom = false

    private let columns = [GridItem(.adaptive(minimum: 210), spacing: 12)]

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(folder.orderedSlots) { slot in
                        TerrainSlotCell(
                            slot: slot,
                            onDrop: { handleDrop($0, into: slot) },
                            onConvert: { mutate { slot.convertToSnapshot() } },
                            onSaveToLibrary: { saveToLibrary(slot) },
                            onClear: { mutate { slot.clear() } }
                        )
                    }
                }
                .padding()
            }
        }
        .navigationTitle(folder.name)
        .toolbar { toolbarContent }
        .overlay { if isWorking { TerrainLoadingOverlay(message: workMessage) } }
        .sheet(isPresented: $showShareSheet) {
            TerrainShareSheet(urls: exportURLs)
                .terrainFormPresentationSizing()
        }
        .alert("Export Failed", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
        .task { await catalog.loadIfNeeded() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            TextField("Folder Name", text: $folder.name)
                .textFieldStyle(.roundedBorder)
                .writingToolsBehavior(.limited)
                .frame(maxWidth: 280)
                .onChange(of: folder.name) { _, _ in try? modelContext.save() }

            Spacer()

            Text("\(folder.filledCount) of \(TerrainPreset.all.count) slots filled")
                .font(.subheadline)
                .foregroundStyle(folder.allFilled ? .green : .secondary)
        }
        .padding()
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem {
            Menu {
                Button("Fill Empty with Random", systemImage: "dice") { fillEmpty(.random) }
                Button("Fill Empty with Preset", systemImage: "mountain.2") { fillEmpty(.preset) }
                Divider()
                Toggle("Smart region mix", isOn: $smartMixOnRandom)
            } label: {
                Label("Fill Empty", systemImage: "wand.and.stars")
            }
            .disabled(folder.allFilled || isWorking)
        }
        ToolbarItem {
            Button(action: exportFolder) {
                Label("Export…", systemImage: "square.and.arrow.up")
            }
            .help(folder.allFilled ? "Export this set as voxelgeneratorsettings.MXML" : "Fill all 31 slots to export")
            .disabled(!folder.allFilled || isWorking)
        }
    }

    // MARK: - Slot actions

    private func mutate(_ body: () -> Void) {
        body()
        try? modelContext.save()
    }

    private func handleDrop(_ item: TerrainDragItem, into slot: TerrainSlot) {
        guard let terrain = modelContext.model(for: item.terrainID) as? TerrainSetting else { return }
        mutate { slot.link(to: terrain) }
    }

    private func saveToLibrary(_ slot: TerrainSlot) {
        guard let min = slot.resolvedMin, let max = slot.resolvedMax else { return }
        let name = slot.isFilled ? slot.displayLabel : "Saved Slot"
        let setting = TerrainSetting(
            name: name,
            preset: slot.preset ?? TerrainPreset(kind: .floatingIslands, category: .standard),
            min: TerrainMin(min: min),
            max: TerrainMax(max: max),
            isCustom: true
        )
        modelContext.insert(setting)
        try? modelContext.save()
    }

    private func fillEmpty(_ mode: FillMode) {
        Task { @MainActor in
            await catalog.loadIfNeeded()
            isWorking = true
            workMessage = mode == .random ? "Filling with random terrain…" : "Filling with preset terrain…"
            defer { isWorking = false }

            let all = TerrainPreset.all
            let loader = FileLoader()

            for slot in folder.orderedSlots where !slot.isFilled {
                guard all.indices.contains(slot.presetOrder) else { continue }
                let preset = all[slot.presetOrder]

                switch mode {
                case .random:
                    guard let gmin = catalog.globalMin, let gmax = catalog.globalMax else { continue }
                    var minData = gmin
                    var maxData = gmax
                    TerrainEditorOperations.randomizeRoot(minData: &minData, maxData: &maxData, refMin: gmin, refMax: gmax)
                    if smartMixOnRandom {
                        var rng = SystemRandomNumberGenerator()
                        SmartRegionMix.apply(min: &minData, max: &maxData, using: &rng)
                    }
                    if lockLODMax {
                        minData = minData.applyingMaxLOD()
                        maxData = maxData.applyingMaxLOD()
                    }
                    slot.setSnapshot(min: minData, max: maxData, label: smartMixOnRandom ? "Random Mix" : "Random")
                case .preset:
                    if let pair = try? await loader.loadTerrainPair(preset: preset) {
                        slot.setSnapshot(min: pair.min, max: pair.max, label: preset.displayName)
                    }
                }
            }
            try? modelContext.save()
        }
    }

    // MARK: - Export

    private func exportFolder() {
        let entries = TerrainExportService.folderEntries(folder)
#if os(macOS)
        guard let url = chooseSaveFile(defaultName: TerrainRandomBatch.combinedFileName) else { return }
        isWorking = true
        workMessage = "Exporting…"
        Task {
            defer { isWorking = false }
            do {
                try await Task.detached(priority: .userInitiated) {
                    try NMSPropertySerializer.writeCombined(entries, to: url)
                }.value
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
#else
        isWorking = true
        workMessage = "Exporting…"
        Task {
            defer { isWorking = false }
            do {
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent(TerrainRandomBatch.combinedFileName)
                try await Task.detached(priority: .userInitiated) {
                    try NMSPropertySerializer.writeCombined(entries, to: url)
                }.value
                exportURLs = [url]
                showShareSheet = true
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
#endif
    }

#if os(macOS)
    private func chooseSaveFile(defaultName: String) -> URL? {
        let panel = NSSavePanel()
        panel.title = "Export Terrain Set"
        panel.message = "Export this folder's 31 slots as a combined settings file."
        panel.prompt = "Export"
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = defaultName
        return panel.runModal() == .OK ? panel.url : nil
    }
#endif
}

private struct TerrainSlotCell: View {
    let slot: TerrainSlot
    let onDrop: (TerrainDragItem) -> Void
    let onConvert: () -> Void
    let onSaveToLibrary: () -> Void
    let onClear: () -> Void

    @State private var isTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(slot.preset?.displayName ?? "Slot \(slot.presetOrder + 1)")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(slot.isFilled ? Color.accentColor : .secondary)
                Text(slot.displayLabel)
                    .font(.caption)
                    .foregroundStyle(slot.isFilled ? .primary : .secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .padding(10)
        .background(
            (isTargeted ? Color.accentColor.opacity(0.18) : Color.gray.opacity(0.10)),
            in: RoundedRectangle(cornerRadius: 10)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    slot.isFilled ? Color.accentColor.opacity(0.4) : Color.secondary.opacity(0.3),
                    style: StrokeStyle(lineWidth: 1, dash: slot.isFilled ? [] : [4])
                )
        }
        .dropDestination(for: TerrainDragItem.self) { items, _ in
            guard let first = items.first else { return false }
            onDrop(first)
            return true
        } isTargeted: { isTargeted = $0 }
        .contextMenu {
            if slot.isLinked {
                Button("Convert to Snapshot Copy", systemImage: "camera", action: onConvert)
            }
            if slot.isFilled {
                Button("Save to Library", systemImage: "tray.and.arrow.down", action: onSaveToLibrary)
                Button("Clear Slot", systemImage: "xmark.circle", role: .destructive, action: onClear)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(slot.preset?.displayName ?? "Slot"): \(slot.displayLabel)")
    }

    private var icon: String {
        if slot.isLinked { return "link" }
        if slot.isSnapshot { return "camera" }
        return "plus.circle.dashed"
    }
}
