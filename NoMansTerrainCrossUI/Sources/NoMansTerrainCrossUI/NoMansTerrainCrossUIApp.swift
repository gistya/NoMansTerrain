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

    init() {
        let loaded = TerrainStore.default().load()
        _terrains = State(wrappedValue: loaded.terrains)
        _folders = State(wrappedValue: loaded.folders)
    }

    var body: some Scene {
        WindowGroup("NoMansTerrain") {
            HStack(spacing: 0) {
                sidebar.frame(width: 260)
                detail.frame(minWidth: 620)
            }
        }
        .defaultSize(width: 1000, height: 680)
    }

    // MARK: - Sidebar

    @ViewBuilder
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NoMansTerrain").font(.title2)

            HStack(spacing: 6) {
                Button("+ Terrain") { newBlankTerrain() }
                Button("+ Folder") { newFolder() }
            }
            Button("🎲 New Random Set") { newRandomSet() }

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
                                delete: { deleteTerrain(terrain.id) }
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
                                delete: { deleteFolder(folder.id) }
                            )
                        }
                    }
                }
            }

            Spacer()
            if !statusMessage.isEmpty {
                Text(statusMessage).font(.caption)
            }
        }
        .padding(10)
    }

    @ViewBuilder
    private func sidebarRow(
        title: String, subtitle: String, isSelected: Bool,
        select: @escaping () -> Void, delete: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 4) {
            Button("\(isSelected ? "▸ " : "  ")\(title)  ·  \(subtitle)") { select() }
            Spacer()
            Button("✕") { delete() }
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
                FolderDetailView(folder: binding, terrains: terrains, base: BaseTerrain.shared, onExport: exportFolder)
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

    /// Writes a folder's 31 slots to a combined `voxelgeneratorsettings.MXML` under the
    /// store's `Exports` directory (SwiftCrossUI has no native save dialog).
    private func exportFolder(_ folder: StoredFolder) {
        let all = TerrainPreset.all
        let entries: [NMSPropertySerializer.CombinedEntry] = folder.orderedSlots.compactMap { slot in
            guard all.indices.contains(slot.presetOrder),
                  let min = slot.resolvedMin(in: terrains),
                  let max = slot.resolvedMax(in: terrains)
            else { return nil }
            return NMSPropertySerializer.CombinedEntry(name: all[slot.presetOrder].fileBaseName, min: min, max: max)
        }
        let dir = store.directory.appendingPathComponent("Exports", isDirectory: true)
        let url = dir.appendingPathComponent("voxelgeneratorsettings.MXML")
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try NMSPropertySerializer.writeCombined(entries, to: url)
            statusMessage = "Exported \(entries.count) → \(url.path)"
        } catch {
            statusMessage = "Export failed: \(error)"
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
