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
    let onExport: (StoredFolder) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Folder Name", text: nameBinding)

            Text("\(folder.filledCount) of \(TerrainPreset.all.count) slots filled")
                .foregroundColor(folder.allFilled ? .green : .gray)

            HStack(spacing: 6) {
                Button("Fill Empty · Random") { fillRandom(onlyEmpty: true) }
                Button("Fill All · Random") { fillRandom(onlyEmpty: false) }
                Button("🎲 Smart Mix All") { smartMixAll() }
                Button("Clear All") { clearAll() }
            }
            Button("⬆ Export voxelgeneratorsettings.MXML") { onExport(folder) }
                .disabled(!folder.allFilled)

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(folder.orderedSlots, id: \.presetOrder) { slot in
                        slotRow(slot)
                    }
                }
            }
            Spacer()
        }
        .padding(12)
    }

    @ViewBuilder
    private func slotRow(_ slot: StoredSlot) -> some View {
        HStack(spacing: 6) {
            Text("\(slot.presetOrder + 1). \(slot.preset?.displayName ?? "Slot")").frame(width: 190)
            Text(slot.displayLabel(in: terrains)).foregroundColor(slot.isFilled ? .black : .gray)
            Spacer()
            Button("Random") { fillSlotRandom(slot.presetOrder) }
            Button("Clear") { folder.updateSlot(slot.presetOrder) { $0.clear() } }
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
