import SwiftUI

struct MainTabView: View {
    /// Shared so the terrain editor can import the SuperFormula the user designs in the
    /// Playground tab (and the Playground keeps its state across tab switches).
    @State private var superFormulaState = SuperFormulaEditorState()

    var body: some View {
        TabView {
            Tab("Terrain", systemImage: "mountain.2") {
                TerrainEditorRootView()
            }

            Tab("SuperFormula", systemImage: "cube") {
                SuperFormulaEditorView()
            }
        }
        .environment(superFormulaState)
    }
}