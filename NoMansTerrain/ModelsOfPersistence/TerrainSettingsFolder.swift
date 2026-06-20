import Foundation
import SwiftData

/// A staging area for assembling a full custom terrain set: one slot per game terrain
/// position (31 of them), each filled by linking a library terrain, copying a snapshot,
/// or auto-filling. Exported as a single `voxelgeneratorsettings.MXML`.
@Model
final class TerrainSettingsFolder {
    var name: String

    @Relationship(deleteRule: .cascade, inverse: \TerrainSlot.folder)
    var slots: [TerrainSlot] = []

    init(name: String) {
        self.name = name
    }

    /// Slots in game order (the relationship itself is unordered).
    var orderedSlots: [TerrainSlot] {
        slots.sorted { $0.presetOrder < $1.presetOrder }
    }

    var filledCount: Int { slots.lazy.filter(\.isFilled).count }

    var allFilled: Bool {
        slots.count == TerrainPreset.all.count && slots.allSatisfy(\.isFilled)
    }
}

/// One position in a ``TerrainSettingsFolder``. Either empty, **linked** to a library
/// terrain (live), or holding a frozen **snapshot** copy (from a drag-converted slot or
/// an auto-fill).
@Model
final class TerrainSlot {
    /// 0–30, matching `TerrainPreset.all` (which is sorted by game order).
    var presetOrder: Int

    var linkedTerrain: TerrainSetting?
    var snapshotMinData: Data?
    var snapshotMaxData: Data?
    var label: String?

    var folder: TerrainSettingsFolder?

    init(presetOrder: Int) {
        self.presetOrder = presetOrder
    }

    var preset: TerrainPreset? {
        let all = TerrainPreset.all
        return all.indices.contains(presetOrder) ? all[presetOrder] : nil
    }

    var isLinked: Bool { linkedTerrain != nil }
    var isSnapshot: Bool { linkedTerrain == nil && snapshotMinData != nil }
    var isFilled: Bool { linkedTerrain != nil || snapshotMinData != nil }

    var resolvedMin: TkVoxelGeneratorData? {
        if let linkedTerrain { return linkedTerrain.sendableMin }
        return Self.decode(snapshotMinData)
    }

    var resolvedMax: TkVoxelGeneratorData? {
        if let linkedTerrain { return linkedTerrain.sendableMax }
        return Self.decode(snapshotMaxData)
    }

    var displayLabel: String {
        if let linkedTerrain { return linkedTerrain.name }
        return label ?? "Empty"
    }

    // MARK: - Mutation

    /// Live-link this slot to a library terrain (clears any snapshot).
    func link(to terrain: TerrainSetting) {
        linkedTerrain = terrain
        snapshotMinData = nil
        snapshotMaxData = nil
        label = nil
    }

    /// Store a frozen copy of the given data (clears any link).
    func setSnapshot(min: TkVoxelGeneratorData, max: TkVoxelGeneratorData, label: String) {
        linkedTerrain = nil
        snapshotMinData = Self.encode(min)
        snapshotMaxData = Self.encode(max)
        self.label = label
    }

    /// Freeze a linked slot into a snapshot copy at its current values.
    func convertToSnapshot() {
        guard let min = resolvedMin, let max = resolvedMax else { return }
        setSnapshot(min: min, max: max, label: displayLabel)
    }

    func clear() {
        linkedTerrain = nil
        snapshotMinData = nil
        snapshotMaxData = nil
        label = nil
    }

    private static func encode(_ value: TkVoxelGeneratorData) -> Data {
        (try? JSONEncoder().encode(value)) ?? Data()
    }

    private static func decode(_ data: Data?) -> TkVoxelGeneratorData? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(TkVoxelGeneratorData.self, from: data)
    }
}
