import NoMansTerrainCore
import SwiftUI
import SwiftData
#if os(macOS)
import AppKit
#endif

private enum TerrainSidebarSelection: Hashable {
    case saved(PersistentIdentifier)
    case folder(PersistentIdentifier)
}

struct TerrainEditorRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TerrainSetting.name) private var savedSettings: [TerrainSetting]
    @Query(sort: \TerrainSettingsFolder.name) private var folders: [TerrainSettingsFolder]

    @State private var catalog = TerrainLimitsCatalog()
    @State private var selection: TerrainSidebarSelection?
    @State private var activeSession: TerrainEditorSession?
    @State private var activeSessionKey: TerrainSidebarSelection?
    @State private var showNewSheet = false
    @State private var showBlankSheet = false
    @State private var showInsaneSheet = false
    @State private var searchText = ""

    @State private var isExportingInsane = false
    @State private var insaneError: String?
    @State private var showInsaneError = false

    @State private var renamingSetting: TerrainSetting?
    @State private var renameText = ""

    @State private var isGenerating = false
    @State private var genProgress = 0
    @State private var genTotal = TerrainPreset.all.count
    @State private var genError: String?
    @State private var showGenError = false

    /// When on, the random terrain set (and random slot fills) also apply a balanced "smart
    /// region mix" to each random terrain. Shared with the folder grid's fill toggle.
    @AppStorage("terrainSmartMixOnRandom") private var smartMixOnRandom = false

    /// When on, random terrains get every layer's LOD pinned to max (low LODs break in-game).
    /// Mirrors the editor / folder-grid toggle.
    @AppStorage("terrainLockLODMax") private var lockLODMax = false

    private var filteredSettings: [TerrainSetting] {
        guard !searchText.isEmpty else { return savedSettings }
        return savedSettings.filter {
            $0.name.localizedStandardContains(searchText)
                || $0.preset.displayName.localizedStandardContains(searchText)
        }
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } detail: {
            detailColumn
        }
        .navigationTitle("Terrain Editor")
        .task { await catalog.loadIfNeeded() }
        .onChange(of: selection) { _, newValue in
            loadActiveSession(for: newValue)
        }
        .sheet(isPresented: $showNewSheet) {
            NewTerrainDocumentSheet(
                catalog: catalog,
                onCreate: { persistNewSession($0) }
            )
            .terrainFormPresentationSizing()
        }
        .sheet(isPresented: $showBlankSheet) {
            NewBlankTerrainSheet(
                catalog: catalog,
                onCreate: { persistNewSession($0) }
            )
            .terrainFormPresentationSizing()
        }
        .sheet(isPresented: $showInsaneSheet) {
            ClaudeInsaneTerrainSheet(
                catalog: catalog,
                onCreate: { persistNewSession($0) }
            )
            .terrainFormPresentationSizing()
        }
        .overlay {
            if isGenerating {
                generatingOverlay
            } else if isExportingInsane {
                busyOverlay("Building Claude's Insane Terrain…")
            }
        }
        .alert("Generation Failed", isPresented: $showGenError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(genError ?? "Unknown error")
        }
        .alert("Export Failed", isPresented: $showInsaneError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(insaneError ?? "Unknown error")
        }
        .alert(
            "Rename Terrain",
            isPresented: Binding(get: { renamingSetting != nil }, set: { if !$0 { renamingSetting = nil } }),
            presenting: renamingSetting
        ) { setting in
            TextField("Name", text: $renameText)
            Button("Rename") { rename(setting, to: renameText) }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var generatingOverlay: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView(value: Double(genProgress), total: Double(max(genTotal, 1))) {
                    Text("Creating Random Terrain Set…")
                        .font(.headline)
                } currentValueLabel: {
                    Text("\(genProgress) of \(genTotal) slots")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .frame(width: 280)
            }
            .padding(28)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func busyOverlay(_ message: String) -> some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView()
                Text(message).font(.headline)
            }
            .padding(28)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var sidebar: some View {
        List(selection: $selection) {
            if !folders.isEmpty {
                Section("Folders") {
                    ForEach(folders) { folder in
                        TerrainSidebarRow(
                            title: folder.name,
                            subtitle: "\(folder.filledCount)/\(TerrainPreset.all.count) slots",
                            systemImage: "folder"
                        )
                        .tag(TerrainSidebarSelection.folder(folder.persistentModelID))
                    }
                    .onDelete(perform: deleteFolders)
                }
            }

            Section("Saved") {
                if filteredSettings.isEmpty {
                    ContentUnavailableView(
                        searchText.isEmpty ? "No Saved Terrains" : "No Results",
                        systemImage: searchText.isEmpty ? "tray" : "magnifyingglass",
                        description: Text(
                            searchText.isEmpty
                                ? "Use New ▸ Blank (Safe Defaults) to create your first terrain."
                                : "No terrains match \"\(searchText)\"."
                        )
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(filteredSettings) { setting in
                        TerrainSidebarRow(
                            title: setting.name,
                            subtitle: setting.isCustom ? "Custom" : setting.preset.displayName
                        )
                        .tag(TerrainSidebarSelection.saved(setting.persistentModelID))
                        .draggable(TerrainDragItem(terrainID: setting.persistentModelID))
                        .contextMenu {
                            Button("Rename…", systemImage: "pencil") {
                                renameText = setting.name
                                renamingSetting = setting
                            }
                            Button("Duplicate", systemImage: "plus.square.on.square") {
                                duplicateSetting(setting)
                            }
                        }
                    }
                    .onDelete(perform: deleteSettings)
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search terrains")
        .toolbar {
            ToolbarItem {
                Menu {
                    Button("Blank (Safe Defaults)", systemImage: "doc") { showBlankSheet = true }
                    Button("From Preset…", systemImage: "mountain.2") { showNewSheet = true }
                    Button("From Claude's Insane Terrain…", systemImage: "wand.and.stars") { showInsaneSheet = true }
                    Divider()
                    Button("Folder", systemImage: "folder.badge.plus", action: createFolder)
                } label: {
                    Label("New", systemImage: "plus")
                }
            }
#if os(macOS)
            ToolbarItem {
                Menu {
                    Button("New Random Set", systemImage: "dice", action: generateRandomSet)
                    Divider()
                    Toggle("Smart region mix", isOn: $smartMixOnRandom)
                } label: {
                    Label("New Random Set", systemImage: "dice")
                } primaryAction: {
                    generateRandomSet()
                }
                .help("Create a new in-app folder with a random terrain in every one of the 31 slots. Enable “Smart region mix” to also balance every layer's region coverage.")
                .disabled(isGenerating)
            }
            ToolbarItem {
                Button(action: exportInsaneCombined) {
                    Label("Export Claude's Insane Set…", systemImage: "wand.and.stars")
                }
                .help("Write all 31 of Claude's Insane Terrains as a single voxelgeneratorsettings.MXML")
                .disabled(isExportingInsane)
            }
#endif
#if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
#endif
        }
    }

    /// Creates a new in-app terrain folder with a freshly randomized terrain snapshot in
    /// every one of the 31 game slots, then selects it. Runs on the main actor (SwiftData);
    /// `Task.yield()` between slots lets the progress overlay paint.
    private func generateRandomSet() {
        Task { @MainActor in
            await catalog.loadIfNeeded()
            guard let globalMin = catalog.globalMin, let globalMax = catalog.globalMax else {
                genError = "Terrain limits are unavailable, so a random set can't be generated."
                showGenError = true
                return
            }

            isGenerating = true
            genProgress = 0
            genTotal = TerrainPreset.all.count
            defer { isGenerating = false }

            let folder = TerrainSettingsFolder(name: "Random Set")
            modelContext.insert(folder)

            for order in 0..<TerrainPreset.all.count {
                var minData = globalMin
                var maxData = globalMax
                TerrainEditorOperations.randomizeRoot(minData: &minData, maxData: &maxData, refMin: globalMin, refMax: globalMax)
                if smartMixOnRandom {
                    var rng = SystemRandomNumberGenerator()
                    SmartRegionMix.apply(min: &minData, max: &maxData, using: &rng)
                }
                if lockLODMax {
                    minData = minData.applyingMaxLOD()
                    maxData = maxData.applyingMaxLOD()
                }
                let slot = TerrainSlot(presetOrder: order)
                slot.folder = folder
                slot.setSnapshot(min: minData, max: maxData, label: smartMixOnRandom ? "Random Mix" : "Random")
                modelContext.insert(slot)

                genProgress = order + 1
                await Task.yield() // let the progress overlay update between slots
            }

            try? modelContext.save()
            selection = .folder(folder.persistentModelID)
        }
    }

#if os(macOS)
    private func exportInsaneCombined() {
        Task { @MainActor in
            await catalog.loadIfNeeded()
            guard let globalMin = catalog.globalMin, let globalMax = catalog.globalMax else {
                insaneError = "Terrain limits are unavailable, so the insane set can't be built."
                showInsaneError = true
                return
            }
            guard let url = chooseInsaneSaveFile() else { return }

            isExportingInsane = true
            defer { isExportingInsane = false }

            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }

            let base = SendableTerrain(min: globalMin, max: globalMax)
            do {
                try await Task.detached(priority: .userInitiated) {
                    let entries = ClaudeInsaneTerrains.combinedEntries(base: base)
                    try NMSPropertySerializer.writeCombined(entries, to: url)
                }.value
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } catch {
                insaneError = error.localizedDescription
                showInsaneError = true
            }
        }
    }

    private func chooseInsaneSaveFile() -> URL? {
        let panel = NSSavePanel()
        panel.title = "Export Claude's Insane Terrain"
        panel.message = "Writes all 31 insane terrains into one combined settings file."
        panel.prompt = "Export"
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = TerrainRandomBatch.combinedFileName
        return panel.runModal() == .OK ? panel.url : nil
    }
#endif

    @ViewBuilder
    private var detailColumn: some View {
        switch selection {
        case .saved:
            if let activeSession {
                TerrainEditorDetailView(
                    session: activeSession,
                    catalog: catalog,
                    existingSetting: existingSetting(for: activeSessionKey)
                )
                .id(activeSessionKey)
            } else {
                emptyDetailPlaceholder
            }
        case .folder(let id):
            if let folder = folders.first(where: { $0.persistentModelID == id }) {
                TerrainFolderGridView(folder: folder, catalog: catalog)
                    .id(id)
            } else {
                emptyDetailPlaceholder
            }
        case nil:
            emptyDetailPlaceholder
        }
    }

    private var emptyDetailPlaceholder: some View {
        ContentUnavailableView(
            "Select or Create Terrain",
            systemImage: "mountain.2",
            description: Text("Pick a saved terrain, or use New ▸ Blank (Safe Defaults) to create one.")
        )
    }

    /// Persists a freshly created terrain immediately so it appears in the sidebar and
    /// can't be lost, then selects it (the detail view reloads from the saved record and
    /// autosaves subsequent edits).
    private func persistNewSession(_ session: TerrainEditorSession) {
        let setting = TerrainSetting(
            name: session.name,
            preset: session.preset,
            min: TerrainMin(min: session.minData),
            max: TerrainMax(max: session.maxData),
            isCustom: session.isCustom
        )
        modelContext.insert(setting)
        try? modelContext.save()
        selection = .saved(setting.persistentModelID)
    }

    /// Creates an independent copy of a saved terrain (its own data, a unique name) and
    /// selects it for editing.
    private func duplicateSetting(_ setting: TerrainSetting) {
        let copy = TerrainSetting(
            name: uniqueCopyName(for: setting.name),
            preset: setting.preset,
            min: TerrainMin(min: setting.sendableMin),
            max: TerrainMax(max: setting.sendableMax),
            isCustom: setting.isCustom
        )
        modelContext.insert(copy)
        try? modelContext.save()
        selection = .saved(copy.persistentModelID)
    }

    /// Renames a terrain. If it's the one currently open in the editor, the live session
    /// is updated too so the change sticks (otherwise the next autosave would overwrite it).
    private func rename(_ setting: TerrainSetting, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if case .saved(let id) = activeSessionKey, id == setting.persistentModelID {
            activeSession?.name = trimmed
        }
        setting.name = trimmed
        try? modelContext.save()
    }

    private func uniqueCopyName(for name: String) -> String {
        let base = "\(name) copy"
        let existing = Set(savedSettings.map(\.name))
        guard existing.contains(base) else { return base }
        var index = 2
        while existing.contains("\(base) \(index)") { index += 1 }
        return "\(base) \(index)"
    }

    private func loadActiveSession(for selection: TerrainSidebarSelection?) {
        guard selection != activeSessionKey else { return }
        activeSessionKey = selection

        switch selection {
        case .saved(let id):
            guard let setting = savedSettings.first(where: { $0.persistentModelID == id }) else {
                activeSession = nil
                return
            }
            activeSession = TerrainEditorSession.fromSetting(setting)
        case .folder, nil:
            activeSession = nil
        }
    }

    private func createFolder() {
        let folder = TerrainSettingsFolder(name: "Terrain Set")
        modelContext.insert(folder)
        for order in 0..<TerrainPreset.all.count {
            let slot = TerrainSlot(presetOrder: order)
            slot.folder = folder
            modelContext.insert(slot)
        }
        try? modelContext.save()
        selection = .folder(folder.persistentModelID)
    }

    private func deleteFolders(at offsets: IndexSet) {
        let foldersToDelete = offsets.map { folders[$0] }
        for folder in foldersToDelete {
            if case .folder(let id) = selection, id == folder.persistentModelID {
                selection = nil
            }
            modelContext.delete(folder)
        }
    }

    private func existingSetting(for key: TerrainSidebarSelection?) -> TerrainSetting? {
        guard case .saved(let id) = key else { return nil }
        return savedSettings.first { $0.persistentModelID == id }
    }

    private func deleteSettings(at offsets: IndexSet) {
        let settingsToDelete = offsets.map { filteredSettings[$0] }
        for setting in settingsToDelete {
            if case .saved(let id) = selection, id == setting.persistentModelID {
                selection = nil
            }
            modelContext.delete(setting)
        }
    }
}

struct NewTerrainDocumentSheet: View {
    @Environment(\.dismiss) private var dismiss

    let catalog: TerrainLimitsCatalog
    let onCreate: (TerrainEditorSession) -> Void

    @State private var selectedPresetID = ""
    @State private var customName = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var presets: [TerrainPreset] {
        catalog.availablePresets.isEmpty ? TerrainPreset.all : catalog.availablePresets
    }

    private var selectedPreset: TerrainPreset? {
        presets.first { $0.id == selectedPresetID }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Bundle Preset") {
                    Picker("Terrain", selection: $selectedPresetID) {
                        Text("Choose preset…").tag("")
                        ForEach(presets) { preset in
                            Text(preset.displayName).tag(preset.id)
                        }
                    }
                    .onChange(of: selectedPresetID) { _, newValue in
                        if customName.isEmpty, let preset = presets.first(where: { $0.id == newValue }) {
                            customName = preset.displayName
                        }
                    }
                }

                Section("Document") {
                    TextField("Name", text: $customName)
                        .writingToolsBehavior(.limited)
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("New Terrain")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { createDocument() }
                        .disabled(selectedPreset == nil || isLoading)
                }
            }
            .overlay {
                if isLoading {
                    TerrainLoadingOverlay(message: "Loading terrain files…")
                }
            }
        }
        .frame(minWidth: 360, minHeight: 280)
    }

    private func createDocument() {
        guard let preset = selectedPreset else { return }
        isLoading = true
        errorMessage = nil

        Task { @MainActor in
            do {
                let loader = FileLoader()
                let pair = try await loader.loadTerrainPair(preset: preset)
                let session = TerrainEditorSession.fromBundle(preset: preset, pair: pair)
                session.name = customName.isEmpty ? preset.displayName : customName
                onCreate(session)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

/// Creates a brand-new terrain seeded with known-safe defaults (Workflow A): the widest
/// of the aggregated and documented limits on every field. Only a name is required.
struct NewBlankTerrainSheet: View {
    @Environment(\.dismiss) private var dismiss

    let catalog: TerrainLimitsCatalog
    let onCreate: (TerrainEditorSession) -> Void

    @State private var name = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Document") {
                    TextField("Name", text: $name)
                        .writingToolsBehavior(.limited)
                }

                Section {
                    Text("Starts every field at its widest known-safe range, ready to tweak. Changes are saved automatically.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("New Blank Terrain")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { createDocument() }
                        .disabled(trimmedName.isEmpty || isLoading)
                }
            }
            .overlay {
                if isLoading {
                    TerrainLoadingOverlay(message: "Preparing terrain…")
                }
            }
        }
        .frame(minWidth: 360, minHeight: 240)
    }

    private func createDocument() {
        isLoading = true
        errorMessage = nil

        Task { @MainActor in
            await catalog.loadIfNeeded()
            guard let globalMin = catalog.globalMin, let globalMax = catalog.globalMax else {
                errorMessage = catalog.loadError ?? "Terrain limits are unavailable."
                isLoading = false
                return
            }

            var minData = globalMin
            var maxData = globalMax
            TerrainEditorOperations.applySafeDefaults(min: &minData, max: &maxData)

            let session = TerrainEditorSession(
                name: trimmedName,
                preset: TerrainPreset(kind: .floatingIslands, category: .standard),
                minData: minData,
                maxData: maxData
            )
            session.isCustom = true
            onCreate(session)
            dismiss()
            isLoading = false
        }
    }
}

/// Lets the user pick one of the 31 "Claude's Insane Terrain" recipes to open as an
/// editable (Custom) terrain.
struct ClaudeInsaneTerrainSheet: View {
    @Environment(\.dismiss) private var dismiss

    let catalog: TerrainLimitsCatalog
    let onCreate: (TerrainEditorSession) -> Void

    @State private var terrains: [InsaneTerrain] = []
    @State private var selectedID: Int?
    @State private var errorMessage: String?

    private var selected: InsaneTerrain? {
        terrains.first { $0.id == selectedID }
    }

    var body: some View {
        NavigationStack {
            Group {
                if terrains.isEmpty {
                    if let errorMessage {
                        ContentUnavailableView("Unavailable", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                    } else {
                        TerrainLoadingOverlay(message: "Conjuring 31 insane worlds…")
                    }
                } else {
                    List(terrains, selection: $selectedID) { terrain in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(terrain.displayName)
                                .font(.headline)
                            Text(terrain.blurb)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                        .tag(terrain.id)
                    }
                }
            }
            .navigationTitle("Claude's Insane Terrain")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { create() }
                        .disabled(selected == nil)
                }
            }
        }
        .frame(minWidth: 420, minHeight: 440)
        .task { await load() }
    }

    private func load() async {
        await catalog.loadIfNeeded()
        guard let globalMin = catalog.globalMin, let globalMax = catalog.globalMax else {
            errorMessage = catalog.loadError ?? "Terrain limits are unavailable."
            return
        }
        let base = SendableTerrain(min: globalMin, max: globalMax)
        terrains = ClaudeInsaneTerrains.generate(base: base)
        selectedID = terrains.first?.id
    }

    private func create() {
        guard let terrain = selected else { return }
        let session = TerrainEditorSession(
            name: terrain.displayName,
            preset: terrain.preset,
            minData: terrain.min,
            maxData: terrain.max
        )
        session.isCustom = true
        onCreate(session)
        dismiss()
    }
}
