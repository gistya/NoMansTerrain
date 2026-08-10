import Foundation
import NoMansTerrainCore
import SwiftCrossUI

/// Editor for a ``StoredFolder`` — the 31 game slots that assemble one combined
/// `voxelgeneratorsettings.MXML`. Slots are filled with randomized snapshots (SwiftCrossUI
/// has no drag-and-drop, so linking library terrains is done via the per-slot picker), then
/// exported. Edits flow through the `folder` binding, which the app persists.
struct FolderDetailView: View {
    @Binding var folder: StoredFolder
    let terrains: [StoredTerrain]
    let base: SendableTerrain
    /// Loads the tapped slot's terrain into the sidebar library (linked) and selects it.
    let onEditSlot: (StoredSlot) -> Void

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

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(folder.orderedSlots, id: \.presetOrder) { slot in
                        slotRow(slot)
                    }
                }
            }
            // Fill the detail pane instead of a fixed 600pt, which clipped the slot controls.
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer()
        }
        .padding(12)
    }

    @ViewBuilder
    private func slotRow(_ slot: StoredSlot) -> some View {
        // No Spacer: at small window sizes a Spacer pushes the trailing buttons off the
        // right edge. Packing left keeps every control visible.
        HStack(spacing: 6) {
            Text("\(slot.presetOrder + 1). \(slot.preset?.displayName ?? "Slot")")
                .frame(width: 130, alignment: .leading)
            Button("🎲") { fillSlotRandom(slot.presetOrder) }
            Button("✕") { folder.updateSlot(slot.presetOrder) { $0.clear() } }
            if slot.isFilled {
                // Tap the terrain to load it into the sidebar library as an editable,
                // linked terrain (🔗 once linked). Also gives the label readable contrast.
                Button("\(slot.isLinked ? "🔗 " : "✎ ")\(slot.displayLabel(in: terrains))") { onEditSlot(slot) }
            } else {
                Text("Empty").foregroundColor(.gray)
            }
        }
    }

    // MARK: - Bindings & actions

    private var nameBinding: Binding<String> {
        Binding(get: { folder.name }, set: { folder.name = $0 })
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
