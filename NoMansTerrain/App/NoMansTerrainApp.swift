//
//  Nah_Bruh_s_TerrainApp.swift
//  Nah Bruh's Terrain
//
//  Created by Jonathan Gilbert on 6/15/26.
//

import SwiftUI
import SwiftData

@main
struct NoMansTerrainApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(for: TerrainSetting.self)
        .defaultSize(width: 1200, height: 800)
    }
}
