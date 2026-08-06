import DefaultBackend
import Foundation
import NoMansTerrainCore
import SwiftCrossUI

/// The cross-platform (Windows / Linux / macOS) NoMansTerrain app, in pure Swift via
/// SwiftCrossUI on top of the shared `NoMansTerrainCore`. Persistence is the portable JSON
/// `TerrainStore` (the SwiftData replacement); all terrain logic is reused from the core.
@main
struct NoMansTerrainCrossUIApp: App {
    /// What the sidebar has selected.
    enum Selection: Equatable {
        case terrain(UUID)
        case folder(UUID)
    }

    private let store = TerrainStore.default()

    @State var terrains: [StoredTerrain]
    @State var folders: [StoredFolder]
    @State var selection: Selection?
    @State var statusMessage = ""
    /// The terrain/folder awaiting a delete confirmation (nil when no dialog is up).
    @State var pendingDelete: Selection?

    init() {
        let loaded = TerrainStore.default().load()
        _terrains = State(wrappedValue: loaded.terrains)
        _folders = State(wrappedValue: loaded.folders)
    }

    var body: some Scene {
        WindowGroup("NoMansTerrain") {
            // Capture the delete target for the alert's action. SwiftCrossUI's alert clears
            // `isPresented` (→ nils `pendingDelete` via the binding below) *before* invoking
            // the pressed button's action, so the action can't read `pendingDelete` back — it
            // must use this captured value instead.
            let deleteTarget = pendingDelete
            VStack(spacing: 0) {
                toolbar
                HStack(spacing: 0) {
                    sidebar.frame(width: 210)
                    detail.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            // Dark gray window background (instead of the backend's default black).
            .background(Color(white: 0.17))
            // Confirm before deleting a terrain or folder.
            .alert(
                deleteAlertTitle,
                isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
            ) {
                Button("Cancel") { pendingDelete = nil }
                Button("Delete") { performDelete(deleteTarget) }
            }
        }
        .defaultSize(width: 1000, height: 680)
    }

    // MARK: - Top toolbar

    @ViewBuilder
    private var toolbar: some View {
        HStack(spacing: 8) {
            Text("NoMansTerrain").font(.title2)
            Button("+ Terrain") { newBlankTerrain() }
            Button("+ Folder") { newFolder() }
            Button("🎲 New Set") { newRandomSet() }
            Button("🏔 Base Set") { newBaseSet() }
            Spacer()
            if !statusMessage.isEmpty {
                Text(statusMessage).font(.caption)
            }
            // Presents a native "save as" dialog to pick the destination, then writes the MXML.
            ExportButton(prepare: prepareExport, onStatus: { statusMessage = $0 })
        }
        .padding(10)
    }

    // MARK: - Sidebar

    @ViewBuilder
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    if !terrains.isEmpty {
                        Text("Terrains").font(.headline)
                        ForEach(terrains, id: \.id) { terrain in
                            sidebarRow(
                                title: terrain.name,
                                subtitle: terrain.isCustom ? "Custom" : terrain.preset.displayName,
                                isSelected: selection == .terrain(terrain.id),
                                select: { selection = .terrain(terrain.id) },
                                delete: { pendingDelete = .terrain(terrain.id) }
                            )
                        }
                    }
                    if !folders.isEmpty {
                        Text("Folders").font(.headline)
                        ForEach(folders, id: \.id) { folder in
                            sidebarRow(
                                title: folder.name,
                                subtitle: "\(folder.filledCount)/\(TerrainPreset.all.count) slots",
                                isSelected: selection == .folder(folder.id),
                                select: { selection = .folder(folder.id) },
                                delete: { pendingDelete = .folder(folder.id) }
                            )
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(10)
    }

    @ViewBuilder
    private func sidebarRow(
        title: String, subtitle: String, isSelected: Bool,
        select: @escaping () -> Void, delete: @escaping () -> Void
    ) -> some View {
        // Title + delete on one line, subtitle as a caption beneath. No Spacer: a Spacer here
        // expands the row to the (oversized) proposed width, which blows the 260-wide sidebar
        // out and shoves the detail pane off-screen. Without it the sidebar sizes to content.
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Button("\(isSelected ? "▸ " : "  ")\(title)") { select() }
                Button("✕") { delete() }
            }
            Text(subtitle).font(.caption).foregroundColor(.gray)
        }
    }

    // MARK: - Detail routing

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .terrain(let id):
            if let binding = terrainBinding(id) {
                TerrainDetailView(terrain: binding)
            } else {
                placeholder("Select a terrain")
            }
        case .folder(let id):
            if let binding = folderBinding(id) {
                FolderDetailView(
                    folder: binding,
                    terrains: terrains,
                    base: BaseTerrain.shared,
                    onEditSlot: { slot in editSlotTerrain(folderID: id, slot: slot) }
                )
            } else {
                placeholder("Select a folder")
            }
        case nil:
            placeholder("Select a terrain or folder, or create one")
        }
    }

    @ViewBuilder
    private func placeholder(_ text: String) -> some View {
        VStack {
            Spacer()
            Text(text).foregroundColor(.gray)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Bindings (persist on write)

    private func terrainBinding(_ id: UUID) -> Binding<StoredTerrain>? {
        guard terrains.contains(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { terrains.first { $0.id == id } ?? terrains[0] },
            set: { newValue in
                if let idx = terrains.firstIndex(where: { $0.id == id }) {
                    terrains[idx] = newValue
                    try? store.saveTerrains(terrains)
                }
            }
        )
    }

    private func folderBinding(_ id: UUID) -> Binding<StoredFolder>? {
        guard folders.contains(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { folders.first { $0.id == id } ?? folders[0] },
            set: { newValue in
                if let idx = folders.firstIndex(where: { $0.id == id }) {
                    folders[idx] = newValue
                    try? store.saveFolders(folders)
                }
            }
        )
    }

    // MARK: - Actions

    private func newBlankTerrain() {
        let base = BaseTerrain.shared
        let terrain = StoredTerrain(
            name: "New Terrain \(terrains.count + 1)",
            preset: TerrainPreset.all[0],
            min: base.min, max: base.max, isCustom: true
        )
        terrains.append(terrain)
        try? store.saveTerrains(terrains)
        selection = .terrain(terrain.id)
    }

    private func newFolder() {
        let folder = StoredFolder.empty(name: "Terrain Set \(folders.count + 1)")
        folders.append(folder)
        try? store.saveFolders(folders)
        selection = .folder(folder.id)
    }

    private func newRandomSet() {
        let base = BaseTerrain.shared
        var folder = StoredFolder.empty(name: "Random Set \(folders.count + 1)")
        for order in 0..<TerrainPreset.all.count {
            var minData = base.min
            var maxData = base.max
            TerrainEditorOperations.randomizeRoot(minData: &minData, maxData: &maxData, refMin: base.min, refMax: base.max)
            folder.updateSlot(order) { $0.setSnapshot(min: minData, max: maxData, label: "Random") }
        }
        folders.append(folder)
        try? store.saveFolders(folders)
        selection = .folder(folder.id)
        statusMessage = "Created \(folder.name)"
    }

    /// Creates a set whose 31 slots hold the game's actual base terrains, loaded from the bundled
    /// per-preset XML (mirrors the macOS "Fill with Preset"). `FileLoader` is an actor and the XML
    /// parse is off the main thread, so load asynchronously and update state when done.
    private func newBaseSet() {
        let presets = TerrainPreset.all
        let setNumber = folders.count + 1
        statusMessage = "Creating base set…"
        Task {
            let loader = FileLoader()
            var folder = StoredFolder.empty(name: "Base Set \(setNumber)")
            var loaded = 0
            for order in 0..<presets.count {
                let preset = presets[order]
                guard let pair = try? await loader.loadTerrainPair(preset: preset, in: .module) else { continue }
                folder.updateSlot(order) { $0.setSnapshot(min: pair.min, max: pair.max, label: preset.displayName) }
                loaded += 1
            }
            folders.append(folder)
            try? store.saveFolders(folders)
            selection = .folder(folder.id)
            statusMessage = loaded == presets.count
                ? "Created \(folder.name)"
                : "Created \(folder.name) — \(loaded)/\(presets.count) base terrains loaded"
        }
    }

    private func deleteTerrain(_ id: UUID) {
        terrains.removeAll { $0.id == id }
        try? store.saveTerrains(terrains)
        if selection == .terrain(id) { selection = nil }
    }

    private func deleteFolder(_ id: UUID) {
        folders.removeAll { $0.id == id }
        try? store.saveFolders(folders)
        if selection == .folder(id) { selection = nil }
    }

    // MARK: - Delete confirmation

    private var deleteAlertTitle: String {
        switch pendingDelete {
        case .terrain(let id):
            return "Delete terrain “\(terrains.first { $0.id == id }?.name ?? "")”? This can’t be undone."
        case .folder(let id):
            return "Delete folder “\(folders.first { $0.id == id }?.name ?? "")”? This can’t be undone."
        case nil:
            return ""
        }
    }

    private func performDelete(_ target: Selection?) {
        switch target {
        case .terrain(let id): deleteTerrain(id)
        case .folder(let id): deleteFolder(id)
        case nil: break
        }
        pendingDelete = nil
    }

    // MARK: - Export (toolbar)

    /// Builds the combined-export entries + suggested filename for the currently-selected
    /// folder, or returns nil (after setting a status hint) if there's nothing to export.
    /// The actual save-destination dialog + write happens in ``ExportButton``.
    private func prepareExport() -> (entries: [NMSPropertySerializer.CombinedEntry], suggestedName: String)? {
        guard case .folder(let id) = selection, let folder = folders.first(where: { $0.id == id }) else {
            statusMessage = "Select a folder to export."
            return nil
        }
        guard folder.allFilled else {
            statusMessage = "Fill all \(TerrainPreset.all.count) slots of “\(folder.name)” before exporting."
            return nil
        }
        let all = TerrainPreset.all
        let entries: [NMSPropertySerializer.CombinedEntry] = folder.orderedSlots.compactMap { slot in
            guard all.indices.contains(slot.presetOrder),
                  let min = slot.resolvedMin(in: terrains),
                  let max = slot.resolvedMax(in: terrains)
            else { return nil }
            return NMSPropertySerializer.CombinedEntry(name: all[slot.presetOrder].fileBaseName, min: min, max: max)
        }
        return (entries, "voxelgeneratorsettings.MXML")
    }

    /// Loads a folder slot's terrain into the sidebar library as an editable, *linked*
    /// terrain, then selects it. If the slot is already linked to a library terrain, just
    /// selects that one. A snapshot slot is promoted: its frozen Min/Max become a new
    /// `StoredTerrain` in the library and the slot is re-linked to it, so edits made in the
    /// sidebar editor flow back to the slot (and the eventual export).
    private func editSlotTerrain(folderID: UUID, slot: StoredSlot) {
        // Already linked to a live library terrain → just open it.
        if let linkedID = slot.linkedTerrainID, terrains.contains(where: { $0.id == linkedID }) {
            selection = .terrain(linkedID)
            return
        }
        guard let min = slot.resolvedMin(in: terrains), let max = slot.resolvedMax(in: terrains) else { return }
        let preset = slot.preset ?? TerrainPreset.all[0]
        let terrain = StoredTerrain(
            name: slot.label ?? preset.displayName,
            preset: preset,
            min: min, max: max,
            isCustom: true
        )
        terrains.append(terrain)
        try? store.saveTerrains(terrains)
        if let idx = folders.firstIndex(where: { $0.id == folderID }) {
            folders[idx].updateSlot(slot.presetOrder) { $0.link(to: terrain.id) }
            try? store.saveFolders(folders)
        }
        selection = .terrain(terrain.id)
    }
}

/// Toolbar export button. Lives in its own `View` so it can read the
/// `chooseFileSaveDestination` environment action (only wired up inside a window's view
/// tree). On tap it asks the parent for the export entries, presents the platform's native
/// "save as" dialog to pick the destination, then writes the combined `.MXML`.
struct ExportButton: View {
    @Environment(\.chooseFileSaveDestination) private var chooseSaveDestination
    /// Supplies the entries + a suggested filename, or nil (having set a status) if nothing
    /// is exportable.
    let prepare: () -> (entries: [NMSPropertySerializer.CombinedEntry], suggestedName: String)?
    let onStatus: (String) -> Void

    var body: some View {
        Button("⬆ Export Set") {
            guard let export = prepare() else { return }
            Task {
                guard let chosen = await chooseSaveDestination(
                    title: "Export Terrain Set",
                    message: "Choose where to save the combined voxelgeneratorsettings file.",
                    defaultButtonLabel: "Export",
                    defaultFileName: export.suggestedName
                ) else { return } // user cancelled

                // The game expects the `.MXML` extension; some backends' save pickers force a
                // different one (WinUI hardcodes `.txt`), so normalise the chosen path.
                var url = chosen
                if url.pathExtension.caseInsensitiveCompare("MXML") != .orderedSame {
                    url.deletePathExtension()
                    url.appendPathExtension("MXML")
                    // Windows' save picker creates an empty placeholder at the chosen path;
                    // remove it so only the real `.MXML` is left behind.
                    if url != chosen {
                        try? FileManager.default.removeItem(at: chosen)
                    }
                }
                do {
                    try NMSPropertySerializer.writeCombined(export.entries, to: url)
                    onStatus("Exported \(export.entries.count) layers → \(url.path)")
                } catch {
                    onStatus("Export failed: \(error)")
                }
            }
        }
    }
}

/// The aggregated base terrain (min/max) bundled as `base.json`, used to seed new and
/// randomized terrains — the cross-platform stand-in for the macOS catalog's globalMin/Max.
enum BaseTerrain {
    static let shared: SendableTerrain = load()

    private static func load() -> SendableTerrain {
        guard let url = Bundle.module.url(forResource: "base", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let pair = try? JSONDecoder().decode([TkVoxelGeneratorData].self, from: data),
              pair.count == 2
        else {
            fatalError("Missing or invalid bundled base.json resource")
        }
        return SendableTerrain(min: pair[0], max: pair[1])
    }
}
