import Foundation
import Hastings

typealias Parser = HastingsXML.XMLParser

class FileLoader {
    let fileManager: FileManager = .default
    private(set) var mins: [TkVoxelGeneratorData] = []
    private(set) var maxs: [TkVoxelGeneratorData] = []
    private(set) var limitsMerger: TerrainLimitsMerger
    private(set) var skippedFiles: [String] = []

    init(bundle: Bundle = .main) {
        limitsMerger = TerrainLimitsMerger(bundle: bundle)
        mins = limitsMerger.mins
        maxs = limitsMerger.maxs
        skippedFiles = limitsMerger.skippedFiles

        if !skippedFiles.isEmpty {
            print("Skipped \(skippedFiles.count) terrain limit files:")
            skippedFiles.forEach { print("  - \($0)") }
        }

        print("Loaded \(mins.count) Min files and \(maxs.count) Max files.")
        if let aggregatedMin = limitsMerger.aggregatedMin,
           let aggregatedMax = limitsMerger.aggregatedMax {
            print("Aggregated production limits:")
            print("  SeaLevel min=\(aggregatedMin.seaLevel) max=\(aggregatedMax.seaLevel)")
            print("  BeachHeight min=\(aggregatedMin.beachHeight) max=\(aggregatedMax.beachHeight)")
        }
    }

    @discardableResult
    func writeProductionLimits(to directory: URL) throws -> (minURL: URL, maxURL: URL) {
        try limitsMerger.writeAggregated(to: directory)
    }
}