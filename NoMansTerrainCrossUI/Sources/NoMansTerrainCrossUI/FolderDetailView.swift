import Foundation
import NoMansTerrainCore
import SwiftCrossUI

/// Editor for a ``StoredFolder`` — the 31 game slots that assemble one combined
/// `voxelgeneratorsettings.MXML`. Slots are shown as a responsive grid of cells that reflows to
/// the window width (SwiftCrossUI has no `Grid`, so the column count is computed from a
/// `GeometryReader`'s proposed width). A cell can be filled by randomizing it, or by assigning a
/// library terrain from the sidebar via its per-cell "Assign" menu (SwiftCrossUI has no
/// drag-and-drop). Assigning *links* the slot to that terrain so later edits flow through.
struct FolderDetailView: View {
    @Binding var folder: StoredFolder
    let terrains: [StoredTerrain]
    let base: SendableTerrain
    /// Loads the tapped slot's terrain into the sidebar library (linked) and selects it.
    let onEditSlot: (StoredSlot) -> Void

    /// Fixed cell width; the grid fits as many of these across the pane as will go.
    private let cellWidth = 232.0
    /// Gap between cells (Int: SwiftCrossUI stack spacing is integral).
    private let cellSpacing = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Folder Name", text: nameBinding)

            Text("\(folder.filledCount) of \(TerrainPreset.all.count) slots filled")
                .foregroundColor(folder.allFilled ? .green : .gray)

            // Horizontally scrollable so the action row never forces the detail pane wider
            // than the window (which previously pushed controls off-screen). Export lives in
            // the app's top toolbar.
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    Button("Fill Empty · Random") { fillRandom(onlyEmpty: true) }
                    Button("Fill All · Random") { fillRandom(onlyEmpty: false) }
                    Button("🎲 Smart Mix All") { smartMixAll() }
                    Button("Clear All") { clearAll() }
                }
            }

            // The grid reflows to the pane width: GeometryReader reports the space available,
            // and we pack `columnCount` fixed-width cells per row, scrolling vertically.
            GeometryReader { proxy in
                let columns = columnCount(for: proxy.size.width)
                ScrollView {
                    VStack(alignment: .leading, spacing: cellSpacing) {
                        ForEach(rows(columns: columns), id: \.index) { row in
                            HStack(alignment: .top, spacing: cellSpacing) {
                                ForEach(row.slots, id: \.presetOrder) { slot in
                                    slotCell(slot)
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(12)
    }

    // MARK: - Grid layout

    /// How many `cellWidth` cells fit across `width` (at least one).
    private func columnCount(for width: Double) -> Int {
        // During measurement passes the pane may propose an infinite (or unspecified→huge) width;
        // `Int(.infinity)` traps, so fall back to a single column until a finite width arrives.
        guard width.isFinite, width > 0 else { return 1 }
        let gap = Double(cellSpacing)
        let columns = Int((width + gap) / (cellWidth + gap))
        return max(1, min(columns, TerrainPreset.all.count))
    }

    /// A row of slots plus a stable identity for `ForEach` (the array is re-chunked whenever the
    /// column count changes on resize).
    private struct SlotRow { let index: Int; let slots: [StoredSlot] }

    private func rows(columns: Int) -> [SlotRow] {
        let ordered = folder.orderedSlots
        guard columns > 0 else { return [SlotRow(index: 0, slots: ordered)] }
        var result: [SlotRow] = []
        var start = 0
        while start < ordered.count {
            let end = min(start + columns, ordered.count)
            result.append(SlotRow(index: result.count, slots: Array(ordered[start..<end])))
            start = end
        }
        return result
    }

    // MARK: - Cell

    @ViewBuilder
    private func slotCell(_ slot: StoredSlot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // The game slot position (fixed identity), e.g. "1. Floating Islands".
            Text("\(slot.presetOrder + 1). \(slot.preset?.displayName ?? "Slot")")
                .font(.caption)
                .foregroundColor(.gray)

            // Current contents — tap to load into the sidebar as an editable, linked terrain
            // (🔗 once linked). Snapshot slots show ✎.
            if slot.isFilled {
                Button("\(slot.isLinked ? "🔗 " : "✎ ")\(slot.displayLabel(in: terrains))") { onEditSlot(slot) }
            } else {
                Text("Empty").foregroundColor(.gray)
            }

            HStack(spacing: 4) {
                // Assign a library terrain from the sidebar into this slot (links it).
                if !terrains.isEmpty {
                    Menu("Assign ▾") {
                        ForEach(terrains, id: \.id) { terrain in
                            Button(terrain.name) { assign(terrain, to: slot.presetOrder) }
                        }
                    }
                }
                Button("🎲") { fillSlotRandom(slot.presetOrder) }
                Button("✕") { folder.updateSlot(slot.presetOrder) { $0.clear() } }
            }
        }
        .padding(8)
        .frame(width: cellWidth, alignment: .leading)
        .background(Color(white: 0.22))
        .cornerRadius(6)
    }

    // MARK: - Bindings & actions

    private var nameBinding: Binding<String> {
        Binding(get: { folder.name }, set: { folder.name = $0 })
    }

    /// Links the slot to a library terrain so the two stay in sync (edits to the terrain flow to
    /// the slot and the export). Mutating `folder` flips the app's unsaved-changes flag.
    private func assign(_ terrain: StoredTerrain, to order: Int) {
        folder.updateSlot(order) { $0.link(to: terrain.id) }
    }

    private func fillSlotRandom(_ order: Int) {
        var mn = base.min
        var mx = base.max
        TerrainEditorOperations.randomizeRoot(minData: &mn, maxData: &mx, refMin: base.min, refMax: base.max)
        folder.updateSlot(order) { $0.setSnapshot(min: mn, max: mx, label: "Random") }
    }

    private func fillRandom(onlyEmpty: Bool) {
        for order in 0..<TerrainPreset.all.count {
            if onlyEmpty, folder.slots.first(where: { $0.presetOrder == order })?.isFilled == true { continue }
            fillSlotRandom(order)
        }
    }

    private func smartMixAll() {
        for order in 0..<TerrainPreset.all.count {
            var mn = base.min
            var mx = base.max
            TerrainEditorOperations.randomizeRoot(minData: &mn, maxData: &mx, refMin: base.min, refMax: base.max)
            var rng = SystemRandomNumberGenerator()
            SmartRegionMix.apply(min: &mn, max: &mx, using: &rng)
            folder.updateSlot(order) { $0.setSnapshot(min: mn, max: mx, label: "Random Mix") }
        }
    }

    private func clearAll() {
        for order in 0..<TerrainPreset.all.count {
            folder.updateSlot(order) { $0.clear() }
        }
    }
}
