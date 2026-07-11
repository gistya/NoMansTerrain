import Foundation

/// Portable, framework-agnostic persistence models — the cross-platform (Windows/Linux)
/// stand-in for the macOS app's SwiftData `@Model` types (`TerrainSetting`,
/// `TerrainSettingsFolder`, `TerrainSlot`). These are plain `Codable` value types persisted
/// as JSON by ``TerrainStore``; no SwiftData, no SwiftUI. The SwiftUI/SwiftData app keeps
/// its own models — these mirror their shape so behavior stays identical.

/// A saved terrain in the library (mirrors `TerrainSetting`).
public struct StoredTerrain: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    public var preset: TerrainPreset
    public var min: TkVoxelGeneratorData
    public var max: TkVoxelGeneratorData
    /// True for terrains created blank rather than cloned from a bundle preset; drives the
    /// "Custom" sidebar label instead of a borrowed preset name.
    public var isCustom: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        preset: TerrainPreset,
        min: TkVoxelGeneratorData,
        max: TkVoxelGeneratorData,
        isCustom: Bool = false
    ) {
        self.id = id
        self.name = name
        self.preset = preset
        self.min = min
        self.max = max
        self.isCustom = isCustom
    }
}

/// One position in a ``StoredFolder`` (mirrors `TerrainSlot`). Either empty, **linked** to a
/// library terrain by id (live), or holding a frozen **snapshot** copy.
public struct StoredSlot: Codable, Sendable, Equatable, Identifiable {
    /// 0–30, matching `TerrainPreset.all` (sorted by game order). Also the stable identity.
    public var presetOrder: Int
    public var linkedTerrainID: UUID?
    public var snapshotMin: TkVoxelGeneratorData?
    public var snapshotMax: TkVoxelGeneratorData?
    public var label: String?

    public var id: Int { presetOrder }

    public init(presetOrder: Int) {
        self.presetOrder = presetOrder
    }

    public var preset: TerrainPreset? {
        let all = TerrainPreset.all
        return all.indices.contains(presetOrder) ? all[presetOrder] : nil
    }

    public var isLinked: Bool { linkedTerrainID != nil }
    public var isSnapshot: Bool { linkedTerrainID == nil && snapshotMin != nil }
    public var isFilled: Bool { linkedTerrainID != nil || snapshotMin != nil }

    /// Linked → the library terrain's Min; snapshot → the frozen Min. Needs the library to
    /// resolve a link (value types can't hold an object reference).
    public func resolvedMin(in terrains: [StoredTerrain]) -> TkVoxelGeneratorData? {
        if let linkedTerrainID { return terrains.first { $0.id == linkedTerrainID }?.min }
        return snapshotMin
    }

    public func resolvedMax(in terrains: [StoredTerrain]) -> TkVoxelGeneratorData? {
        if let linkedTerrainID { return terrains.first { $0.id == linkedTerrainID }?.max }
        return snapshotMax
    }

    public func displayLabel(in terrains: [StoredTerrain]) -> String {
        if let linkedTerrainID { return terrains.first { $0.id == linkedTerrainID }?.name ?? "Empty" }
        return label ?? "Empty"
    }

    // MARK: - Mutation

    public mutating func link(to terrainID: UUID) {
        linkedTerrainID = terrainID
        snapshotMin = nil
        snapshotMax = nil
        label = nil
    }

    public mutating func setSnapshot(min: TkVoxelGeneratorData, max: TkVoxelGeneratorData, label: String) {
        linkedTerrainID = nil
        snapshotMin = min
        snapshotMax = max
        self.label = label
    }

    /// Freeze a linked slot into a snapshot at its current resolved values.
    public mutating func convertToSnapshot(in terrains: [StoredTerrain]) {
        guard let min = resolvedMin(in: terrains), let max = resolvedMax(in: terrains) else { return }
        setSnapshot(min: min, max: max, label: displayLabel(in: terrains))
    }

    public mutating func clear() {
        linkedTerrainID = nil
        snapshotMin = nil
        snapshotMax = nil
        label = nil
    }
}

/// A staging area for a full custom terrain set: one slot per game terrain position (31 of
/// them). Mirrors `TerrainSettingsFolder`.
public struct StoredFolder: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    public var slots: [StoredSlot]

    public init(id: UUID = UUID(), name: String, slots: [StoredSlot]) {
        self.id = id
        self.name = name
        self.slots = slots
    }

    /// A new folder with one empty slot per game terrain position.
    public static func empty(name: String) -> StoredFolder {
        StoredFolder(name: name, slots: (0..<TerrainPreset.all.count).map(StoredSlot.init(presetOrder:)))
    }

    /// Slots in game order (the array itself may be unordered).
    public var orderedSlots: [StoredSlot] {
        slots.sorted { $0.presetOrder < $1.presetOrder }
    }

    public var filledCount: Int { slots.lazy.filter(\.isFilled).count }

    public var allFilled: Bool {
        slots.count == TerrainPreset.all.count && slots.allSatisfy(\.isFilled)
    }

    /// In-place mutation of the slot at `presetOrder`, if present.
    public mutating func updateSlot(_ presetOrder: Int, _ body: (inout StoredSlot) -> Void) {
        guard let idx = slots.firstIndex(where: { $0.presetOrder == presetOrder }) else { return }
        body(&slots[idx])
    }
}
