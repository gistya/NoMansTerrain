import NoMansTerrainCore
//
//  ContentView.swift
//  Nah Bruh's Terrain
//
//  Created by Jonathan Gilbert on 6/15/26.
//

import SwiftUI
import SwiftData

//var y: _SwiftContext? = nil

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var terrainSettings: [TerrainSetting]

    var body: some View {
//        NavigationSplitView {
//            List {
//                ForEach(terrainSettings) { terrainSetting in
//                    NavigationLink {
//                        // TODO: implement editor for terrain settings with "set from default minimums" and "randomize within valid ranges" etc.
//                        EmptyView()
//                    } label: {
//                        Text("Placeholder")
//                    }
//                }
//                .onDelete(perform: deleteItems)
//            }
#if os(macOS)
//            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
#endif
//            .toolbar {
#if os(iOS)
//                ToolbarItem(placement: .navigationBarTrailing) {
//                    EditButton()
//                }
#endif
//                ToolbarItem {
//                    Button(action: addItem) {
//                        Label("Add Item", systemImage: "plus")
//                    }
//                }
//            }
//        } detail: {
//            Text("Select an item")
//        }
    }

//    private func addItem() {
//        withAnimation {
//            let newItem = TerrainSetting(timestamp: Date())
//            modelContext.insert(newItem)
//        }
//    }

//    private func deleteItems(offsets: IndexSet) {
//        withAnimation {
//            for index in offsets {
//                modelContext.delete(TerrainSetting[index])
//            }
//        }
//    }
}

#Preview {
//    ContentView()
//        .modelContainer(for: Item.self, inMemory: true)
}
