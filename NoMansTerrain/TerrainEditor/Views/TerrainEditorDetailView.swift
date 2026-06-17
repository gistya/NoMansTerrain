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

    init(name: String, preset: TerrainPreset, minData: TkVoxelGeneratorData, maxData: TkVoxelGeneratorData) {
        self.name = name
        self.preset = preset
        self.minData = minData
        self.maxData = maxData
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
        setting.min = TerrainMin(min: minData)
        setting.max = TerrainMax(max: maxData)
    }

    var nameBinding: Binding<String> {
        Binding(
            get: { self.name },
            set: { self.name = $0; self.isDirty = true }
        )
    }

    var minDataBinding: Binding<TkVoxelGeneratorData> {
        Binding(
            get: { self.minData },
            set: { self.minData = $0; self.isDirty = true }
        )
    }

    var maxDataBinding: Binding<TkVoxelGeneratorData> {
        Binding(
            get: { self.maxData },
            set: { self.maxData = $0; self.isDirty = true }
        )
    }
}

struct TerrainEditorDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var session: TerrainEditorSession
    let catalog: TerrainLimitsCatalog
    var existingSetting: TerrainSetting?
    var onSave: ((TerrainSetting) -> Void)?

    @State private var selectedSection: TerrainEditorSection = .general

    init(
        session: TerrainEditorSession,
        catalog: TerrainLimitsCatalog,
        existingSetting: TerrainSetting? = nil,
        onSave: ((TerrainSetting) -> Void)? = nil
    ) {
        _session = State(initialValue: session)
        self.catalog = catalog
        self.existingSetting = existingSetting
        self.onSave = onSave
    }
    @State private var exportURLs: [URL] = []
    @State private var showShareSheet = false
    @State private var exportError: String?
    @State private var showExportError = false
    @State private var didSaveRecently = false
    @State private var saveError: String?
    @State private var showSaveError = false

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
                editorForm(session: session, globalMin: globalMin, globalMax: globalMax)
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
        HStack(spacing: 12) {
            Image(systemName: didSaveRecently ? "checkmark.circle.fill" : (session.isDirty ? "pencil.circle" : "tray.full"))
                .foregroundStyle(didSaveRecently ? .green : (session.isDirty ? .orange : .secondary))
            Text(didSaveRecently ? "Saved to Library" : (session.isDirty ? "Unsaved changes" : "Up to date"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .animation(.snappy, value: didSaveRecently)

            Spacer()

            Button {
                saveDocument()
            } label: {
                Label("Save to Library", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut("s", modifiers: .command)
            .disabled(existingSetting != nil && !session.isDirty)
        }
        .padding(.horizontal)
        .padding(.top)
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
        ToolbarItemGroup {
            Button("Save", systemImage: "square.and.arrow.down", action: saveDocument)
                .help("Save terrain to library")
            Button("Share XML…", systemImage: "square.and.arrow.up", action: shareXML)
                .help("Export min/max XML files")
#if os(macOS)
            Button("Save to Folder…", systemImage: "folder", action: saveToFolder)
                .help("Write XML files to a folder on disk")
#endif
        }
    }

    private func saveDocument() {
        let setting: TerrainSetting
        if let existingSetting {
            session.apply(to: existingSetting)
            setting = existingSetting
        } else {
            let newSetting = TerrainSetting(
                name: session.name,
                preset: session.preset,
                min: TerrainMin(min: session.minData),
                max: TerrainMax(max: session.maxData)
            )
            modelContext.insert(newSetting)
            setting = newSetting
        }

        // SwiftData autosaves, but persist explicitly so failures surface immediately
        // rather than silently at some later checkpoint.
        do {
            try modelContext.save()
        } catch {
            saveError = error.localizedDescription
            showSaveError = true
            return
        }

        session.isDirty = false
        onSave?(setting)

        withAnimation(.snappy) { didSaveRecently = true }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.snappy) { didSaveRecently = false }
        }
    }

    private func shareXML() {
        Task { @MainActor in
            do {
                exportURLs = try await TerrainExportService.writeXMLPairToTemporaryDirectory(
                    preset: session.preset,
                    minData: session.minData,
                    maxData: session.maxData
                )
                showShareSheet = true
            } catch {
                exportError = error.localizedDescription
                showExportError = true
            }
        }
    }

#if os(macOS)
    private func saveToFolder() {
        Task { @MainActor in
            do {
                let urls = try await TerrainExportService.writeXMLPairToTemporaryDirectory(
                    preset: session.preset,
                    minData: session.minData,
                    maxData: session.maxData
                )
                if let destination = try TerrainFolderSaver.save(
                    urls: urls,
                    suggestedFolderName: session.preset.fileBaseName
                ) {
                    NSWorkspace.shared.activateFileViewerSelecting([destination])
                }
            } catch {
                exportError = error.localizedDescription
                showExportError = true
            }
        }
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
                    Text("Share these files via AirDrop, Mail, or “Save to Files”. To write them straight to a folder on disk, use “Save to Folder…” in the editor toolbar.")
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

#if os(macOS)
enum TerrainFolderSaver {
    /// Prompts for a destination folder and copies `urls` into a subfolder there.
    /// Returns the destination folder, or `nil` if the user cancelled. Throws (rather
    /// than silently swallowing) on any filesystem failure so callers can report it.
    @discardableResult
    @MainActor
    static func save(urls: [URL], suggestedFolderName: String) throws -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Choose Folder"
        panel.message = "Choose where to save the Min/Max XML files."
        panel.prompt = "Save"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let directory = panel.url else { return nil }

        let accessed = directory.startAccessingSecurityScopedResource()
        defer { if accessed { directory.stopAccessingSecurityScopedResource() } }

        let destination = directory.appendingPathComponent(suggestedFolderName, isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

        for url in urls {
            let target = destination.appendingPathComponent(url.lastPathComponent)
            if FileManager.default.fileExists(atPath: target.path) {
                try FileManager.default.removeItem(at: target)
            }
            try FileManager.default.copyItem(at: url, to: target)
        }

        return destination
    }
}
#endif