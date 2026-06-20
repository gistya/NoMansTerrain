//
//  Item.swift
//  Nah Bruh's Terrain
//
//  Created by Jonathan Gilbert on 6/15/26.
//

import Foundation
import SwiftData

/// Persisted terrain document.
///
/// The terrain payload (`preset`, `min`, `max`) is stored as encoded `Data` rather
/// than as direct model properties. SwiftData stores a nested `Codable` struct as a
/// *composite attribute*, flattening it into one SQLite column per leaf field. The
/// terrain structs have hundreds of nested fields, which blows past SQLite's column
/// limit ("too many columns on ZTERRAINSETTING") and prevents the store from opening
/// at all. Encoding to a handful of `Data` columns keeps the schema small while
/// preserving the same typed API for callers.
@Model
final class TerrainSetting {
    var name: String

    /// True for terrains created blank (Workflow A) rather than cloned from a bundle
    /// preset; drives the "Custom" sidebar label instead of a borrowed preset name.
    var isCustom: Bool = false

    private var presetData: Data
    private var minData: Data
    private var maxData: Data

    /// Folder slots that link (live-reference) this terrain. Nullified when the terrain
    /// is deleted, so those slots simply become empty.
    @Relationship(deleteRule: .nullify, inverse: \TerrainSlot.linkedTerrain)
    var linkingSlots: [TerrainSlot] = []

    init(
        name: String,
        preset: TerrainPreset,
        min: TerrainMin,
        max: TerrainMax,
        isCustom: Bool = false
    ) {
        self.name = name
        self.isCustom = isCustom
        self.presetData = Self.encode(preset)
        self.minData = Self.encode(min)
        self.maxData = Self.encode(max)
    }

    var preset: TerrainPreset {
        get { Self.decode(presetData) }
        set { presetData = Self.encode(newValue) }
    }

    var min: TerrainMin {
        get { Self.decode(minData) }
        set { minData = Self.encode(newValue) }
    }

    var max: TerrainMax {
        get { Self.decode(maxData) }
        set { maxData = Self.encode(newValue) }
    }

    var sendableMin: TkVoxelGeneratorData { min.min }
    var sendableMax: TkVoxelGeneratorData { max.max }

    private static func encode<T: Encodable>(_ value: T) -> Data {
        do {
            return try JSONEncoder().encode(value)
        } catch {
            assertionFailure("Failed to encode \(T.self): \(error)")
            return Data()
        }
    }

    private static func decode<T: Decodable>(_ data: Data) -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            fatalError("Failed to decode persisted \(T.self): \(error)")
        }
    }
}
