import SwiftUI
import SwiftData

@MainActor
@Observable
final class TerrainEditorSession {
    var name: String
    var preset: TerrainPreset
    var minData: TkVoxelGeneratorData
    var maxData: TkVoxelGeneratorData
    var isDirty = false

    /// Monotonic counter bumped on every committed edit. Observers use it as a cheap
    /// (Int-compare) trigger to schedule an autosave without diffing the huge data structs.
    var revision = 0

    /// Snapshot of what's currently persisted, so autosave can diff sections and write
    /// only the ones that changed. Not observed (no view depends on it).
    @ObservationIgnored var lastPersistedMin: TkVoxelGeneratorData
    @ObservationIgnored var lastPersistedMax: TkVoxelGeneratorData

    init(name: String, preset: TerrainPreset, minData: TkVoxelGeneratorData, maxData: TkVoxelGeneratorData) {
        self.name = name
        self.preset = preset
        self.minData = minData
        self.maxData = maxData
        self.lastPersistedMin = minData
        self.lastPersistedMax = maxData
    }

    static func fromBundle(preset: TerrainPreset, pair: SendableTerrain) -> TerrainEditorSession {
        TerrainEditorSession(
            name: preset.displayName,
            preset: preset,
            minData: pair.min,
            maxData: pair.max
        )
    }

    static func fromSetting(_ setting: TerrainSetting) -> TerrainEditorSession {
        TerrainEditorSession(
            name: setting.name,
            preset: setting.preset,
            minData: setting.sendableMin,
            maxData: setting.sendableMax
        )
    }

    func apply(to setting: TerrainSetting) {
        setting.name = name
        setting.preset = preset
        setting.replaceAllSections(min: minData, max: maxData)
    }

    var nameBinding: Binding<String> {
        Binding(
            get: { self.name },
            set: { self.name = $0; self.markEdited() }
        )
    }

    var minDataBinding: Binding<TkVoxelGeneratorData> {
        Binding(
            get: { self.minData },
            set: { self.minData = $0; self.markEdited() }
        )
    }

    var maxDataBinding: Binding<TkVoxelGeneratorData> {
        Binding(
            get: { self.maxData },
            set: { self.maxData = $0; self.markEdited() }
        )
    }

    private func markEdited() {
        isDirty = true
        revision &+= 1
    }
}

struct TerrainEditorDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var session: TerrainEditorSession
    let catalog: TerrainLimitsCatalog
    var existingSetting: TerrainSetting?

    @State private var selectedSection: TerrainEditorSection = .general

    init(
        session: TerrainEditorSession,
        catalog: TerrainLimitsCatalog,
        existingSetting: TerrainSetting? = nil
    ) {
        _session = State(initialValue: session)
        self.catalog = catalog
        self.existingSetting = existingSetting
    }
    @State private var exportURLs: [URL] = []
    @State private var showShareSheet = false
    @State private var exportError: String?
    @State private var showExportError = false

    private enum AutosaveStatus: Equatable { case saved, saving, failed }
    @State private var autosaveStatus: AutosaveStatus = .saved
    @State private var autosaveTask: Task<Void, Never>?
    @State private var saveError: String?
    @State private var showSaveError = false

    /// Source the "Lowest Mins"/"Highest Maxes" buttons pull from: the observed safe range
    /// across existing terrains (false) or the absolute documented limits (true).
    @AppStorage("terrainUseAbsoluteLimits") private var useAbsoluteLimits = false

    /// When on, Set Min/Max and Randomize preserve each layer's `active` flag.
    /// Read independently by every `SectionActionBar` via the same key.
    @AppStorage("terrainLockActive") private var lockActive = false

    private enum TerrainEditorSection: String, CaseIterable, Identifiable {
        case general, noiseLayers, gridLayers, features, caves

        var id: String { rawValue }

        var title: String {
            switch self {
            case .general: "General"
            case .noiseLayers: "Noise"
            case .gridLayers: "Grid"
            case .features: "Features"
            case .caves: "Caves"
            }
        }
    }

    var body: some View {
        @Bindable var session = session

        Group {
            if let globalMin = catalog.globalMin, let globalMax = catalog.globalMax {
                let (effMin, effMax) = applyLimitSource(globalMin, globalMax)
                editorForm(session: session, globalMin: effMin, globalMax: effMax)
            } else if catalog.isLoading {
                ProgressView("Loading terrain limits…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView(
                    "Limits Unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text(catalog.loadError ?? "Could not load bundle terrain limits.")
                )
            }
        }
        .navigationTitle(session.name)
        .toolbar { toolbarContent }
        .onChange(of: session.revision) { _, _ in scheduleAutosave() }
        .onDisappear { flushAutosave() }
        .sheet(isPresented: $showShareSheet) {
            TerrainShareSheet(urls: exportURLs)
                .terrainFormPresentationSizing()
        }
        .alert("Export Failed", isPresented: $showExportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "Unknown error")
        }
        .alert("Save Failed", isPresented: $showSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "Unknown error")
        }
    }

    @ViewBuilder
    private func saveBar(session: TerrainEditorSession) -> some View {
        HStack(spacing: 8) {
            switch autosaveStatus {
            case .saving:
                ProgressView().controlSize(.small)
                Text("Saving…").font(.subheadline).foregroundStyle(.secondary)
            case .saved:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("All changes saved").font(.subheadline).foregroundStyle(.secondary)
            case .failed:
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text("Save failed").font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()

            Toggle("Lock active", isOn: $lockActive)
                .toggleStyle(.switch)
                .controlSize(.small)
                .help("When on, Set Min/Max and Randomize leave each layer's Active flag unchanged.")

            Toggle("Absolute limits", isOn: $useAbsoluteLimits)
                .toggleStyle(.switch)
                .controlSize(.small)
                .help("When on, the Set Min/Max buttons snap fields to the absolute documented limits; when off, to the known-safe range observed across existing terrains.")
        }
        .animation(.snappy, value: autosaveStatus == .saving)
        .padding(.horizontal)
        .padding(.top)
    }

    /// Globals the Set Min/Max buttons pull from. Documented field ranges and randomize
    /// already use the documented limits directly, so swapping these only changes the
    /// "Lowest Mins"/"Highest Maxes" buttons' behavior.
    private func applyLimitSource(
        _ globalMin: TkVoxelGeneratorData,
        _ globalMax: TkVoxelGeneratorData
    ) -> (TkVoxelGeneratorData, TkVoxelGeneratorData) {
        guard useAbsoluteLimits else { return (globalMin, globalMax) }
        var mn = globalMin
        var mx = globalMax
        TerrainEditorOperations.applyAbsoluteBounds(min: &mn, max: &mx)
        return (mn, mx)
    }

    @ViewBuilder
    private func editorForm(
        session: TerrainEditorSession,
        globalMin: TkVoxelGeneratorData,
        globalMax: TkVoxelGeneratorData
    ) -> some View {
        VStack(spacing: 0) {
            saveBar(session: session)

            Picker("Section", selection: $selectedSection) {
                ForEach(TerrainEditorSection.allCases) { section in
                    Text(section.title).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            sectionContent(session: session, globalMin: globalMin, globalMax: globalMax)
        }
    }

    @ViewBuilder
    private func sectionContent(
        session: TerrainEditorSession,
        globalMin: TkVoxelGeneratorData,
        globalMax: TkVoxelGeneratorData
    ) -> some View {
        switch selectedSection {
        case .general:
            RootTerrainFormEditor(
                session: session,
                globalMin: globalMin,
                globalMax: globalMax,
                preset: session.preset
            )
        case .noiseLayers:
            NoiseLayersTabbedEditor(
                minLayers: session.minDataBinding.nested(\.noiseLayers),
                maxLayers: session.maxDataBinding.nested(\.noiseLayers),
                globalMin: globalMin.noiseLayers,
                globalMax: globalMax.noiseLayers
            )
        case .gridLayers:
            GridLayersTabbedEditor(
                minLayers: session.minDataBinding.nested(\.gridLayers),
                maxLayers: session.maxDataBinding.nested(\.gridLayers),
                globalMin: globalMin.gridLayers,
                globalMax: globalMax.gridLayers
            )
        case .features:
            FeaturesTabbedEditor(
                minFeatures: session.minDataBinding.nested(\.features),
                maxFeatures: session.maxDataBinding.nested(\.features),
                globalMin: globalMin.features,
                globalMax: globalMax.features
            )
        case .caves:
            CavesTabbedEditor(
                minCaves: session.minDataBinding.nested(\.caves),
                maxCaves: session.maxDataBinding.nested(\.caves),
                globalMin: globalMin.caves,
                globalMax: globalMax.caves
            )
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem {
            Menu {
                Button("Split Min/Max Files…", systemImage: "square.split.2x1", action: exportSplit)
                Button("Full TerrainSettings File…", systemImage: "doc.fill", action: exportFull)
                    .help("Use this terrain's Min/Max for all 31 preset slots")
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
        }
    }

    // MARK: - Autosave

    private func scheduleAutosave() {
        autosaveTask?.cancel()
        autosaveStatus = .saving
        autosaveTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.6))
            if Task.isCancelled { return }
            commitAutosave()
        }
    }

    private func flushAutosave() {
        autosaveTask?.cancel()
        autosaveTask = nil
        if autosaveStatus != .saved { commitAutosave() }
    }

    private func commitAutosave() {
        guard let setting = existingSetting else { return }
        let name = session.name
        let preset = session.preset
        let curMin = session.minData
        let curMax = session.maxData
        let lastMin = session.lastPersistedMin
        let lastMax = session.lastPersistedMax

        Task {
            // Heavy part off the main thread: diff sections and encode only what changed.
            let (minChanges, maxChanges) = await Task.detached(priority: .userInitiated) {
                (TerrainSetting.changedSections(old: lastMin, new: curMin),
                 TerrainSetting.changedSections(old: lastMax, new: curMax))
            }.value

            // Back on the main actor: assign the few changed columns and save.
            setting.name = name
            setting.preset = preset
            setting.applySections(minChanges, to: .min)
            setting.applySections(maxChanges, to: .max)
            do {
                try modelContext.save()
                session.lastPersistedMin = curMin
                session.lastPersistedMax = curMax
                session.isDirty = false
                autosaveStatus = .saved
            } catch {
                autosaveStatus = .failed
                saveError = error.localizedDescription
                showSaveError = true
            }
        }
    }

    // MARK: - Export

    private func exportSplit() {
#if os(macOS)
        guard let directory = chooseDirectory(message: "Choose a folder for the Min/Max files.") else { return }
        let accessed = directory.startAccessingSecurityScopedResource()
        defer { if accessed { directory.stopAccessingSecurityScopedResource() } }
        do {
            let urls = try TerrainExportService.writeNamedSplitPair(
                name: session.name, minData: session.minData, maxData: session.maxData, to: directory
            )
            NSWorkspace.shared.activateFileViewerSelecting(urls)
        } catch {
            exportError = error.localizedDescription
            showExportError = true
        }
#else
        do {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("terrain-split-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            exportURLs = try TerrainExportService.writeNamedSplitPair(
                name: session.name, minData: session.minData, maxData: session.maxData, to: directory
            )
            showShareSheet = true
        } catch {
            exportError = error.localizedDescription
            showExportError = true
        }
#endif
    }

    private func exportFull() {
        let minData = session.minData
        let maxData = session.maxData
#if os(macOS)
        guard let url = chooseSaveFile(defaultName: TerrainRandomBatch.combinedFileName) else { return }
        Task {
            do {
                try await Task.detached(priority: .userInitiated) {
                    try TerrainExportService.writeFullSettings(minData: minData, maxData: maxData, to: url)
                }.value
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } catch {
                exportError = error.localizedDescription
                showExportError = true
            }
        }
#else
        Task {
            do {
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent(TerrainRandomBatch.combinedFileName)
                try await Task.detached(priority: .userInitiated) {
                    try TerrainExportService.writeFullSettings(minData: minData, maxData: maxData, to: url)
                }.value
                exportURLs = [url]
                showShareSheet = true
            } catch {
                exportError = error.localizedDescription
                showExportError = true
            }
        }
#endif
    }

#if os(macOS)
    private func chooseDirectory(message: String) -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Choose Folder"
        panel.message = message
        panel.prompt = "Export"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func chooseSaveFile(defaultName: String) -> URL? {
        let panel = NSSavePanel()
        panel.title = "Export TerrainSettings"
        panel.message = "This terrain's Min/Max will be used for every preset slot."
        panel.prompt = "Export"
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = defaultName
        return panel.runModal() == .OK ? panel.url : nil
    }
#endif
}

#if os(iOS)
import UIKit

struct TerrainShareSheet: UIViewControllerRepresentable {
    let urls: [URL]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: urls, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#elseif os(macOS)
import AppKit

struct TerrainShareSheet: View {
    let urls: [URL]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Share these files via AirDrop, Mail, or “Save to Files”.")
                        .foregroundStyle(.secondary)
                }

                Section("Files") {
                    ForEach(urls, id: \.path) { url in
                        LabeledContent(url.lastPathComponent) {
                            Image(systemName: "doc.text")
                                .foregroundStyle(.secondary)
                        }
                        .font(.body.monospaced())
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Share Terrain XML")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    ShareLink(items: urls) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .frame(minWidth: 420, minHeight: 280)
    }
}
#endif

