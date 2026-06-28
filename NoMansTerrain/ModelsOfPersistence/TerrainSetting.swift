@preconcurrency import NoMansTerrainCore
//
//  Item.swift
//  Nah Bruh's Terrain
//
//  Created by Jonathan Gilbert on 6/15/26.
//

import Foundation
import SwiftData

/// One editable section of a terrain. Each maps to a tab in the editor and to its own
/// `Data` column on `TerrainSetting`, so editing one panel only re-encodes that section.
enum TerrainSection: CaseIterable, Sendable {
    case root, noise, grid, features, caves
}

/// The non-collection scalar fields of `TkVoxelGeneratorData` (the "General" tab),
/// split out so they persist independently of the big noise/grid/feature/cave collections.
struct TerrainRootScalars: Codable, Equatable, Sendable {
    var baseSeed: BaseSeed
    var seaLevel: Double
    var beachHeight: Double
    var noSeaBaseLevel: Double
    var buildingVoxelType: TkNoiseVoxelTypeEnum
    var resourceVoxelType: TkNoiseVoxelTypeEnum
    var minimumCaveDepth: Double
    var caveRoofSmoothingDist: Double
    var maximumSeaLevelCaveDepth: Double
    var buildingTextureRadius: Double
    var buildingSmoothingRadius: Double
    var buildingSmoothingHeight: Double
    var waterFadeInDistance: Double

    init(_ d: TkVoxelGeneratorData) {
        baseSeed = d.baseSeed
        seaLevel = d.seaLevel
        beachHeight = d.beachHeight
        noSeaBaseLevel = d.noSeaBaseLevel
        buildingVoxelType = d.buildingVoxelType
        resourceVoxelType = d.resourceVoxelType
        minimumCaveDepth = d.minimumCaveDepth
        caveRoofSmoothingDist = d.caveRoofSmoothingDist
        maximumSeaLevelCaveDepth = d.maximumSeaLevelCaveDepth
        buildingTextureRadius = d.buildingTextureRadius
        buildingSmoothingRadius = d.buildingSmoothingRadius
        buildingSmoothingHeight = d.buildingSmoothingHeight
        waterFadeInDistance = d.waterFadeInDistance
    }
}

/// Persisted terrain document.
///
/// Storage is split **per section** — root scalars, noise layers, grid layers, features,
/// and caves are each encoded into their own `Data` column for both the Min and Max files.
/// Editing one panel re-encodes and writes only that section's column, rather than the
/// whole multi-thousand-field structure. (The structs are stored as `Data` blobs because
/// SwiftData otherwise flattens nested `Codable` structs into one SQLite column per leaf
/// field, which blows past SQLite's column limit and prevents the store from opening.)
@Model
final class TerrainSetting {
    var name: String

    /// True for terrains created blank (Workflow A) rather than cloned from a bundle
    /// preset; drives the "Custom" sidebar label instead of a borrowed preset name.
    var isCustom: Bool = false

    private var presetData: Data

    private var minRootData: Data
    private var minNoiseData: Data
    private var minGridData: Data
    private var minFeaturesData: Data
    private var minCavesData: Data

    private var maxRootData: Data
    private var maxNoiseData: Data
    private var maxGridData: Data
    private var maxFeaturesData: Data
    private var maxCavesData: Data

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

        let mn = min.min
        self.minRootData = Self.encode(TerrainRootScalars(mn))
        self.minNoiseData = Self.encode(mn.noiseLayers)
        self.minGridData = Self.encode(mn.gridLayers)
        self.minFeaturesData = Self.encode(mn.features)
        self.minCavesData = Self.encode(mn.caves)

        let mx = max.max
        self.maxRootData = Self.encode(TerrainRootScalars(mx))
        self.maxNoiseData = Self.encode(mx.noiseLayers)
        self.maxGridData = Self.encode(mx.gridLayers)
        self.maxFeaturesData = Self.encode(mx.features)
        self.maxCavesData = Self.encode(mx.caves)
    }

    var preset: TerrainPreset {
        get { Self.decode(presetData) }
        set { presetData = Self.encode(newValue) }
    }

    var sendableMin: TkVoxelGeneratorData {
        Self.assemble(
            root: Self.decode(minRootData),
            noise: Self.decode(minNoiseData),
            grid: Self.decode(minGridData),
            features: Self.decode(minFeaturesData),
            caves: Self.decode(minCavesData)
        )
    }

    var sendableMax: TkVoxelGeneratorData {
        Self.assemble(
            root: Self.decode(maxRootData),
            noise: Self.decode(maxNoiseData),
            grid: Self.decode(maxGridData),
            features: Self.decode(maxFeaturesData),
            caves: Self.decode(maxCavesData)
        )
    }

    /// Overwrites every section of both files. Used for full saves (e.g. `apply`).
    func replaceAllSections(min: TkVoxelGeneratorData, max: TkVoxelGeneratorData) {
        applySections(Self.encodedSections(of: min), to: .min)
        applySections(Self.encodedSections(of: max), to: .max)
    }

    /// Writes only the provided sections' pre-encoded `Data` (granular autosave path).
    enum Limit { case min, max }
    func applySections(_ data: [TerrainSection: Data], to limit: Limit) {
        for (section, blob) in data {
            switch (limit, section) {
            case (.min, .root): minRootData = blob
            case (.min, .noise): minNoiseData = blob
            case (.min, .grid): minGridData = blob
            case (.min, .features): minFeaturesData = blob
            case (.min, .caves): minCavesData = blob
            case (.max, .root): maxRootData = blob
            case (.max, .noise): maxNoiseData = blob
            case (.max, .grid): maxGridData = blob
            case (.max, .features): maxFeaturesData = blob
            case (.max, .caves): maxCavesData = blob
            }
        }
    }

    // MARK: - Section encoding / diffing (off-main friendly: pure value work)

    /// Encoded `Data` for every section of `data`.
    static func encodedSections(of data: TkVoxelGeneratorData) -> [TerrainSection: Data] {
        [
            .root: encode(TerrainRootScalars(data)),
            .noise: encode(data.noiseLayers),
            .grid: encode(data.gridLayers),
            .features: encode(data.features),
            .caves: encode(data.caves)
        ]
    }

    /// Encoded `Data` for only the sections that differ between `old` and `new`.
    static func changedSections(old: TkVoxelGeneratorData, new: TkVoxelGeneratorData) -> [TerrainSection: Data] {
        var out: [TerrainSection: Data] = [:]
        if TerrainRootScalars(old) != TerrainRootScalars(new) { out[.root] = encode(TerrainRootScalars(new)) }
        if old.noiseLayers != new.noiseLayers { out[.noise] = encode(new.noiseLayers) }
        if old.gridLayers != new.gridLayers { out[.grid] = encode(new.gridLayers) }
        if old.features != new.features { out[.features] = encode(new.features) }
        if old.caves != new.caves { out[.caves] = encode(new.caves) }
        return out
    }

    static func assemble(
        root: TerrainRootScalars,
        noise: NoiseLayers,
        grid: GridLayers,
        features: Features,
        caves: Caves
    ) -> TkVoxelGeneratorData {
        TkVoxelGeneratorData(
            baseSeed: root.baseSeed,
            seaLevel: root.seaLevel,
            beachHeight: root.beachHeight,
            noSeaBaseLevel: root.noSeaBaseLevel,
            buildingVoxelType: root.buildingVoxelType,
            resourceVoxelType: root.resourceVoxelType,
            noiseLayers: noise,
            gridLayers: grid,
            features: features,
            caves: caves,
            minimumCaveDepth: root.minimumCaveDepth,
            caveRoofSmoothingDist: root.caveRoofSmoothingDist,
            maximumSeaLevelCaveDepth: root.maximumSeaLevelCaveDepth,
            buildingTextureRadius: root.buildingTextureRadius,
            buildingSmoothingRadius: root.buildingSmoothingRadius,
            buildingSmoothingHeight: root.buildingSmoothingHeight,
            waterFadeInDistance: root.waterFadeInDistance
        )
    }

    static func encode<T: Encodable>(_ value: T) -> Data {
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
