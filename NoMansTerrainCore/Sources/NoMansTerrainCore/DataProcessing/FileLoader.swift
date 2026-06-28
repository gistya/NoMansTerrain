import Foundation
import Hastings

public typealias XMLParser = HastingsXML.XMLParser
public typealias XMLSerializer = HastingsXML.XMLSerializer

public actor FileLoader {
    private let decoder = XMLDecoder(keyStrategy: .attribute(name: "name", value: "value"))

    public init() {}

    public func makeModelsOfXML(in bundle: Bundle = .main) throws -> [SendableTerrain] {
        let pairs = try matchedTerrainPairs(in: bundle)
        return pairs.map { SendableTerrain(min: $0.min, max: $0.max) }
    }

    public func availablePresets(in bundle: Bundle = .main) throws -> [TerrainPreset] {
        let pairs = try matchedTerrainPairs(in: bundle)
        return pairs.map(\.preset).sorted { $0.displayName < $1.displayName }
    }

    public func loadTerrainPair(preset: TerrainPreset, in bundle: Bundle = .main) throws -> SendableTerrain {
        guard let minURL = bundle.url(forResource: preset.fileBaseName + "_Min", withExtension: "xml"),
              let maxURL = bundle.url(forResource: preset.fileBaseName + "_Max", withExtension: "xml")
        else {
            throw TerrainLimitsMergerError.missingPreset(preset)
        }

        let min = try loadTerrainMin(from: minURL).get()
        let max = try loadTerrainMax(from: maxURL).get()
        return SendableTerrain(min: min, max: max)
    }

    private struct MatchedTerrainPair {
        public var preset: TerrainPreset
        public var min: TkVoxelGeneratorData
        public var max: TkVoxelGeneratorData
    }

    private func matchedTerrainPairs(in bundle: Bundle) throws -> [MatchedTerrainPair] {
        var pairs: [MatchedTerrainPair] = []
        var skipped: [String] = []

        for preset in TerrainPreset.all {
            guard let minURL = bundle.url(forResource: preset.fileBaseName + "_Min", withExtension: "xml"),
                  let maxURL = bundle.url(forResource: preset.fileBaseName + "_Max", withExtension: "xml")
            else { continue }

            do {
                let min = try loadTerrainMin(from: minURL).get()
                let max = try loadTerrainMax(from: maxURL).get()
                pairs.append(MatchedTerrainPair(preset: preset, min: min, max: max))
            } catch {
                skipped.append(preset.minFileName)
            }
        }

        if !skipped.isEmpty {
            print("Skipped terrain pairs: \(skipped)")
        }

        return pairs
    }
    
    @discardableResult
    public func write(terrain: Terrain, data: TkVoxelGeneratorData, to terrainDirectory: URL) throws -> URL {
        
        let dir = terrainDirectory.appendingPathComponent(terrain.limit.rawValue, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let url = dir.appendingPathComponent(terrain.fileName).appendingPathExtension("xml")

        do {
            try NMSPropertySerializer.write(limit: terrain.limit, data, to: url)
        } catch {
            throw TerrainLimitsMergerError.writeFailed(url, error)
        }

        return url
    }

    private func loadTerrainMin(from url: URL) -> Result<TkVoxelGeneratorData, any Error> {
        Result {
            let doc = try parse(xml: url)
            let terrain = try decoder.decode(TerrainMin.self, from: doc.root)
            return terrain.min
        }
    }

    private func loadTerrainMax(from url: URL) -> Result<TkVoxelGeneratorData, any Error> {
        Result {
            let doc = try parse(xml: url)
            let terrain = try decoder.decode(TerrainMax.self, from: doc.root)
            return terrain.max
        }
    }

    private func parse(xml url: URL) throws -> Document {
        let xmlStr = try String(contentsOf: url, encoding: .utf8)
        return try XMLParser().parse(xmlStr)
    }
}

public enum TerrainLimitsMergerError: Error, CustomStringConvertible {
    case noFilesLoaded(kind: String)
    case missingPreset(TerrainPreset)
    case writeFailed(URL, any Error)

    public var description: String {
        switch self {
        case .noFilesLoaded(let kind):
            return "No \(kind) terrain limit files could be loaded."
        case .missingPreset(let preset):
            return "Missing bundle files for \(preset.displayName)."
        case .writeFailed(let url, let error):
            return "Failed to write \(url.lastPathComponent): \(error)"
        }
    }
}
