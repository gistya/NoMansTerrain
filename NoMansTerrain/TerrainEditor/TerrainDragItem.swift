import NoMansTerrainCore
import CoreTransferable
import SwiftData
import UniformTypeIdentifiers

/// Drag payload identifying a library terrain by its persistent id, so it can be dropped
/// onto a folder slot. Resolved back to a `TerrainSetting` via `modelContext.model(for:)`.
struct TerrainDragItem: Codable, Transferable {
    let terrainID: PersistentIdentifier

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .data)
    }
}
