import SwiftUI
import SwiftData

private enum TerrainSidebarSelection: Hashable {
    case draft
    case saved(PersistentIdentifier)
}

struct TerrainEditorRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TerrainSetting.name) private var savedSettings: [TerrainSetting]

    @State private var catalog = TerrainLimitsCatalog()
    @State private var selection: TerrainSidebarSelection?
    @State private var draftSession: TerrainEditorSession?
    @State private var activeSession: TerrainEditorSession?
    @State private var activeSessionKey: TerrainSidebarSelection?
    @State private var showNewSheet = false
    @State private var searchText = ""

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
                onCreate: { session in
                    draftSession = session
                    activeSession = session
                    activeSessionKey = .draft
                    selection = .draft
                }
            )
            .terrainFormPresentationSizing()
        }
    }

    private var sidebar: some View {
        List(selection: $selection) {
            if let draftSession {
                TerrainSidebarRow(
                    title: draftSession.name,
                    subtitle: "Unsaved draft",
                    systemImage: "doc.badge.plus"
                )
                .tag(TerrainSidebarSelection.draft)
            }

            Section("Saved") {
                if filteredSettings.isEmpty {
                    ContentUnavailableView(
                        searchText.isEmpty ? "No Saved Terrains" : "No Results",
                        systemImage: searchText.isEmpty ? "tray" : "magnifyingglass",
                        description: Text(
                            searchText.isEmpty
                                ? "Create a terrain from a bundle preset to get started."
                                : "No terrains match \"\(searchText)\"."
                        )
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(filteredSettings) { setting in
                        TerrainSidebarRow(
                            title: setting.name,
                            subtitle: setting.preset.displayName
                        )
                        .tag(TerrainSidebarSelection.saved(setting.persistentModelID))
                    }
                    .onDelete(perform: deleteSettings)
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search terrains")
        .toolbar {
            ToolbarItem {
                Button {
                    showNewSheet = true
                } label: {
                    Label("New Terrain", systemImage: "plus")
                }
            }
#if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
#endif
        }
    }

    @ViewBuilder
    private var detailColumn: some View {
        if let activeSession {
            TerrainEditorDetailView(
                session: activeSession,
                catalog: catalog,
                existingSetting: existingSetting(for: activeSessionKey),
                onSave: { saved in
                    selection = .saved(saved.persistentModelID)
                    activeSessionKey = .saved(saved.persistentModelID)
                    draftSession = nil
                }
            )
            .id(activeSessionKey)
        } else {
            emptyDetailPlaceholder
        }
    }

    private var emptyDetailPlaceholder: some View {
        ContentUnavailableView(
            "Select or Create Terrain",
            systemImage: "mountain.2",
            description: Text("Load a min/max pair from the bundle or open a saved terrain document.")
        )
    }

    private func loadActiveSession(for selection: TerrainSidebarSelection?) {
        guard selection != activeSessionKey else { return }
        activeSessionKey = selection

        switch selection {
        case .draft:
            activeSession = draftSession
        case .saved(let id):
            guard let setting = savedSettings.first(where: { $0.persistentModelID == id }) else {
                activeSession = nil
                return
            }
            activeSession = TerrainEditorSession.fromSetting(setting)
        case nil:
            activeSession = nil
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
                selection = draftSession != nil ? .draft : nil
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