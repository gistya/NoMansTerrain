import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("Terrain", systemImage: "mountain.2") {
                TerrainEditorRootView()
            }

            Tab("SuperFormula", systemImage: "cube") {
                SuperFormulaEditorView()
            }
        }
    }
}