//
//  Item.swift
//  Nah Bruh's Terrain
//
//  Created by Jonathan Gilbert on 6/15/26.
//

import Foundation

struct SendableTerrain {
    var min: TkVoxelGeneratorData
    var max: TkVoxelGeneratorData
}

extension [SendableTerrain] {
    /// Find the lowest and highest limits of all the mins and maxs.
    /// - Returns: a `SendableTerrain` whose min and max have all the min and max values of all the mins and maxs.
    func aggregate() throws -> SendableTerrain {
        func aggregate(_ values: [TkVoxelGeneratorData], direction: MergeDirection) -> TkVoxelGeneratorData? {
            guard let first = values.first else { return nil }
            return values.dropFirst().reduce(first) { $0.merged(with: $1, direction: direction) }
        }
        
        let mins = map { $0.min }
        let maxs = map { $0.max }
        
        guard let aggregatedMin = aggregate(mins, direction: .minimum),
                let aggregatedMax = aggregate(maxs, direction: .maximum)
        else {
            throw TerrainLimitsMergerError.noFilesLoaded(kind: "Could not compute aggregated min/max.")
        }
        
        return SendableTerrain(min: aggregatedMin, max: aggregatedMax)
    }
}
