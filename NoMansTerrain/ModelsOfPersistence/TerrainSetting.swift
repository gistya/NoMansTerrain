//
//  Item.swift
//  Nah Bruh's Terrain
//
//  Created by Jonathan Gilbert on 6/15/26.
//

import Foundation
import SwiftData

@Model
final class TerrainSetting {
    var name: String
    var preset: TerrainPreset
    var min: TerrainMin
    var max: TerrainMax

    var sendableMin: TkVoxelGeneratorData { min.min }
    var sendableMax: TkVoxelGeneratorData { max.max }

    init(
        name: String,
        preset: TerrainPreset,
        min: TerrainMin,
        max: TerrainMax
    ) {
        self.name = name
        self.preset = preset
        self.min = min
        self.max = max
    }
}
