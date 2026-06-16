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
    var min: TerrainMin
    var max: TerrainMax
    var terrain: Terrain
    
    var sendableMin: TkVoxelGeneratorData { min.min }
    var sendableMax: TkVoxelGeneratorData { max.max }
    
    init(terrain: Terrain, min: TerrainMin, max: TerrainMax) {
        self.terrain = terrain
        self.min = min
        self.max = max
    }
}
