import Foundation

/// Cross-platform JSON persistence for the terrain library and folders — the portable
/// replacement for SwiftData's `ModelContainer` on Windows/Linux. Terrains and folders are
/// each stored as one JSON file in a directory (by default under Application Support).
///
/// The store is intentionally I/O-only and value-based: callers hold the `[StoredTerrain]` /
/// `[StoredFolder]` arrays as their own UI state (which SwiftCrossUI observes natively) and
/// call `save…` after mutations. Terrains and folders persist to separate files so editing
/// one collection never rewrites the other.
public struct TerrainStore: Sendable {
    public let directory: URL
    public let terrainsURL: URL
    public let foldersURL: URL

    public init(directory: URL) {
        self.directory = directory
        self.terrainsURL = directory.appendingPathComponent("terrains.json")
        self.foldersURL = directory.appendingPathComponent("folders.json")
    }

    /// The default per-user store location (e.g. `…/Application Support/NoMansTerrain` on
    /// macOS, `%APPDATA%\NoMansTerrain` on Windows), falling back to a temp dir if the
    /// platform can't resolve Application Support.
    public static func defaultDirectory() -> URL {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )) ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("NoMansTerrain", isDirectory: true)
    }

    public static func `default`() -> TerrainStore {
        TerrainStore(directory: defaultDirectory())
    }

    // MARK: - Load

    /// Loads both collections. Missing or unreadable files yield empty arrays (first launch),
    /// so the store never throws on load — a corrupt file just starts empty rather than
    /// crashing the app.
    public func load() -> (terrains: [StoredTerrain], folders: [StoredFolder]) {
        (loadTerrains(), loadFolders())
    }

    public func loadTerrains() -> [StoredTerrain] {
        decode([StoredTerrain].self, from: terrainsURL) ?? []
    }

    public func loadFolders() -> [StoredFolder] {
        decode([StoredFolder].self, from: foldersURL) ?? []
    }

    // MARK: - Save

    public func saveTerrains(_ terrains: [StoredTerrain]) throws {
        try write(terrains, to: terrainsURL)
    }

    public func saveFolders(_ folders: [StoredFolder]) throws {
        try write(folders, to: foldersURL)
    }

    // MARK: - Helpers

    private func decode<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func write<T: Encodable>(_ value: T, to url: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(value)
        try data.write(to: url, options: .atomic)
    }
}
