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
        // Fill the window and declare a sensible minimum so it stays freely resizable —
        // otherwise tight content (e.g. the Regions histogram) gets cropped with no way to
        // grow the window.
        .frame(minWidth: 900, idealWidth: 1200, maxWidth: .infinity,
               minHeight: 600, idealHeight: 800, maxHeight: .infinity)
    }
}