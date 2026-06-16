import Foundation
import Hastings

typealias XMLParser = HastingsXML.XMLParser
typealias XMLSerializer = HastingsXML.XMLSerializer

actor FileLoader {
    private let decoder = XMLDecoder(keyStrategy: .attribute(name: "name", value: "value"))

    func makeModelsOfXML(in bundle: Bundle = .main) throws -> [SendableTerrain] {
        let minURLs = (bundle.urls(forResourcesWithExtension: "xml", subdirectory: nil) ?? [])
            .filter { $0.lastPathComponent.localizedCaseInsensitiveContains("Min") }
        let maxURLs = (bundle.urls(forResourcesWithExtension: "xml", subdirectory: nil) ?? [])
            .filter { $0.lastPathComponent.localizedCaseInsensitiveContains("Max") }

        var loadedMins: [TkVoxelGeneratorData] = []
        var loadedMaxs: [TkVoxelGeneratorData] = []
        var skipped: [String] = []

        for url in minURLs {
            switch loadTerrainMin(from: url) {
            case .success(let data):
                loadedMins.append(data)
            case .failure:
                skipped.append(url.lastPathComponent)
            }
        }

        for url in maxURLs {
            switch loadTerrainMax(from: url) {
            case .success(let data):
                loadedMaxs.append(data)
            case .failure:
                skipped.append(url.lastPathComponent)
            }
        }
        
        print("Skipped files: \(skipped)")
                
        let settings = zip(loadedMins, loadedMaxs).map { (min, max) in
            SendableTerrain(min: min, max: max)
        }
        
        return settings
    }
    
    @discardableResult
    func write(terrain: Terrain, data: TkVoxelGeneratorData, to terrainDirectory: URL) throws -> URL {
        
        let dir = terrainDirectory.appendingPathComponent(terrain.limit.rawValue, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let url = dir.appendingPathComponent(terrain.fileName)

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

enum TerrainLimitsMergerError: Error, CustomStringConvertible {
    case noFilesLoaded(kind: String)
    case writeFailed(URL, any Error)

    var description: String {
        switch self {
        case .noFilesLoaded(let kind):
            return "No \(kind) terrain limit files could be loaded."
        case .writeFailed(let url, let error):
            return "Failed to write \(url.lastPathComponent): \(error)"
        }
    }
}
