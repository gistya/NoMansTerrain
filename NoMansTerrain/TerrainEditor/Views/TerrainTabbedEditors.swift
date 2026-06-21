import SwiftUI

// MARK: - Noise Layers

private enum NoiseLayerTab: String, CaseIterable, Identifiable {
    case base, hill, mountain, rock, underWater, texture, elevation, continent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .base: "Base"
        case .hill: "Hill"
        case .mountain: "Mountain"
        case .rock: "Rock"
        case .underWater: "Under Water"
        case .texture: "Texture"
        case .elevation: "Elevation"
        case .continent: "Continent"
        }
    }
}

struct NoiseLayersTabbedEditor: View {
    @Binding var minLayers: NoiseLayers
    @Binding var maxLayers: NoiseLayers
    let globalMin: NoiseLayers
    let globalMax: NoiseLayers

    @State private var selectedTab: NoiseLayerTab = .base

    var body: some View {
        VStack(spacing: 0) {
            Picker("Noise Layer", selection: $selectedTab) {
                ForEach(NoiseLayerTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            noiseLayerEditor(for: selectedTab)
        }
    }

    @ViewBuilder
    private func noiseLayerEditor(for tab: NoiseLayerTab) -> some View {
        switch tab {
        case .base:
            UberLayerFormEditor(
                title: tab.title,
                minLayer: $minLayers.nested(\.base),
                maxLayer: $maxLayers.nested(\.base),
                globalMin: globalMin.base,
                globalMax: globalMax.base
            )
        case .hill:
            UberLayerFormEditor(
                title: tab.title,
                minLayer: $minLayers.nested(\.hill),
                maxLayer: $maxLayers.nested(\.hill),
                globalMin: globalMin.hill,
                globalMax: globalMax.hill
            )
        case .mountain:
            UberLayerFormEditor(
                title: tab.title,
                minLayer: $minLayers.nested(\.mountain),
                maxLayer: $maxLayers.nested(\.mountain),
                globalMin: globalMin.mountain,
                globalMax: globalMax.mountain
            )
        case .rock:
            UberLayerFormEditor(
                title: tab.title,
                minLayer: $minLayers.nested(\.rock),
                maxLayer: $maxLayers.nested(\.rock),
                globalMin: globalMin.rock,
                globalMax: globalMax.rock
            )
        case .underWater:
            UberLayerFormEditor(
                title: tab.title,
                minLayer: $minLayers.nested(\.underWater),
                maxLayer: $maxLayers.nested(\.underWater),
                globalMin: globalMin.underWater,
                globalMax: globalMax.underWater
            )
        case .texture:
            UberLayerFormEditor(
                title: tab.title,
                minLayer: $minLayers.nested(\.texture),
                maxLayer: $maxLayers.nested(\.texture),
                globalMin: globalMin.texture,
                globalMax: globalMax.texture
            )
        case .elevation:
            UberLayerFormEditor(
                title: tab.title,
                minLayer: $minLayers.nested(\.elevation),
                maxLayer: $maxLayers.nested(\.elevation),
                globalMin: globalMin.elevation,
                globalMax: globalMax.elevation
            )
        case .continent:
            UberLayerFormEditor(
                title: tab.title,
                minLayer: $minLayers.nested(\.continent),
                maxLayer: $maxLayers.nested(\.continent),
                globalMin: globalMin.continent,
                globalMax: globalMax.continent
            )
        }
    }
}

// MARK: - Grid Layers

private enum GridLayerTab: String, CaseIterable, Identifiable {
    case small, large, resources

    var id: String { rawValue }

    var title: String {
        switch self {
        case .small: "Small"
        case .large: "Large"
        case .resources: "Resources"
        }
    }
}

private enum ResourceGridTab: String, CaseIterable, Identifiable {
    case heridium, iridium, copper, nickel, aluminium, gold, emeril

    var id: String { rawValue }

    var title: String {
        switch self {
        case .heridium: "Heridium"
        case .iridium: "Iridium"
        case .copper: "Copper"
        case .nickel: "Nickel"
        case .aluminium: "Aluminium"
        case .gold: "Gold"
        case .emeril: "Emeril"
        }
    }
}

struct GridLayersTabbedEditor: View {
    @Binding var minLayers: GridLayers
    @Binding var maxLayers: GridLayers
    let globalMin: GridLayers
    let globalMax: GridLayers

    @State private var selectedTab: GridLayerTab = .small

    var body: some View {
        VStack(spacing: 0) {
            Picker("Grid Layer", selection: $selectedTab) {
                ForEach(GridLayerTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            gridLayerEditor(for: selectedTab)
        }
    }

    @ViewBuilder
    private func gridLayerEditor(for tab: GridLayerTab) -> some View {
        switch tab {
        case .small:
            GridLayerFormEditor(
                title: tab.title,
                minLayer: $minLayers.nested(\.small),
                maxLayer: $maxLayers.nested(\.small),
                globalMin: globalMin.small,
                globalMax: globalMax.small
            )
        case .large:
            GridLayerFormEditor(
                title: tab.title,
                minLayer: $minLayers.nested(\.large),
                maxLayer: $maxLayers.nested(\.large),
                globalMin: globalMin.large,
                globalMax: globalMax.large
            )
        case .resources:
            ResourcesGridTabbedEditor(
                minLayers: $minLayers,
                maxLayers: $maxLayers,
                globalMin: globalMin,
                globalMax: globalMax
            )
        }
    }
}

private struct ResourcesGridTabbedEditor: View {
    @Binding var minLayers: GridLayers
    @Binding var maxLayers: GridLayers
    let globalMin: GridLayers
    let globalMax: GridLayers

    @State private var selectedResource: ResourceGridTab = .heridium

    var body: some View {
        VStack(spacing: 0) {
            Picker("Resource", selection: $selectedResource) {
                ForEach(ResourceGridTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal)

            resourceEditor(for: selectedResource)
        }
    }

    @ViewBuilder
    private func resourceEditor(for tab: ResourceGridTab) -> some View {
        switch tab {
        case .heridium:
            GridLayerFormEditor(
                title: tab.title,
                minLayer: $minLayers.nested(\.resourcesHeridium),
                maxLayer: $maxLayers.nested(\.resourcesHeridium),
                globalMin: globalMin.resourcesHeridium,
                globalMax: globalMax.resourcesHeridium
            )
        case .iridium:
            GridLayerFormEditor(
                title: tab.title,
                minLayer: $minLayers.nested(\.resourcesIridium),
                maxLayer: $maxLayers.nested(\.resourcesIridium),
                globalMin: globalMin.resourcesIridium,
                globalMax: globalMax.resourcesIridium
            )
        case .copper:
            GridLayerFormEditor(
                title: tab.title,
                minLayer: $minLayers.nested(\.resourcesCopper),
                maxLayer: $maxLayers.nested(\.resourcesCopper),
                globalMin: globalMin.resourcesCopper,
                globalMax: globalMax.resourcesCopper
            )
        case .nickel:
            GridLayerFormEditor(
                title: tab.title,
                minLayer: $minLayers.nested(\.resourcesNickel),
                maxLayer: $maxLayers.nested(\.resourcesNickel),
                globalMin: globalMin.resourcesNickel,
                globalMax: globalMax.resourcesNickel
            )
        case .aluminium:
            GridLayerFormEditor(
                title: tab.title,
                minLayer: $minLayers.nested(\.resourcesAluminium),
                maxLayer: $maxLayers.nested(\.resourcesAluminium),
                globalMin: globalMin.resourcesAluminium,
                globalMax: globalMax.resourcesAluminium
            )
        case .gold:
            GridLayerFormEditor(
                title: tab.title,
                minLayer: $minLayers.nested(\.resourcesGold),
                maxLayer: $maxLayers.nested(\.resourcesGold),
                globalMin: globalMin.resourcesGold,
                globalMax: globalMax.resourcesGold
            )
        case .emeril:
            GridLayerFormEditor(
                title: tab.title,
                minLayer: $minLayers.nested(\.resourcesEmeril),
                maxLayer: $maxLayers.nested(\.resourcesEmeril),
                globalMin: globalMin.resourcesEmeril,
                globalMax: globalMax.resourcesEmeril
            )
        }
    }
}

// MARK: - Features

private enum FeatureTab: String, CaseIterable, Identifiable {
    case river, crater, arches, archesSmall, blobs, blobsSmall, substance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .river: "River"
        case .crater: "Crater"
        case .arches: "Arches"
        case .archesSmall: "Arches Small"
        case .blobs: "Blobs"
        case .blobsSmall: "Blobs Small"
        case .substance: "Substance"
        }
    }
}

struct FeaturesTabbedEditor: View {
    @Binding var minFeatures: Features
    @Binding var maxFeatures: Features
    let globalMin: Features
    let globalMax: Features

    @State private var selectedTab: FeatureTab = .river

    var body: some View {
        VStack(spacing: 0) {
            Picker("Feature", selection: $selectedTab) {
                ForEach(FeatureTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal)

            featureEditor(for: selectedTab)
        }
    }

    @ViewBuilder
    private func featureEditor(for tab: FeatureTab) -> some View {
        switch tab {
        case .river:
            FeatureFormEditor(
                title: tab.title,
                minFeature: $minFeatures.nested(\.river),
                maxFeature: $maxFeatures.nested(\.river),
                globalMin: globalMin.river,
                globalMax: globalMax.river
            )
        case .crater:
            FeatureFormEditor(
                title: tab.title,
                minFeature: $minFeatures.nested(\.crater),
                maxFeature: $maxFeatures.nested(\.crater),
                globalMin: globalMin.crater,
                globalMax: globalMax.crater
            )
        case .arches:
            FeatureFormEditor(
                title: tab.title,
                minFeature: $minFeatures.nested(\.arches),
                maxFeature: $maxFeatures.nested(\.arches),
                globalMin: globalMin.arches,
                globalMax: globalMax.arches
            )
        case .archesSmall:
            FeatureFormEditor(
                title: tab.title,
                minFeature: $minFeatures.nested(\.archesSmall),
                maxFeature: $maxFeatures.nested(\.archesSmall),
                globalMin: globalMin.archesSmall,
                globalMax: globalMax.archesSmall
            )
        case .blobs:
            FeatureFormEditor(
                title: tab.title,
                minFeature: $minFeatures.nested(\.blobs),
                maxFeature: $maxFeatures.nested(\.blobs),
                globalMin: globalMin.blobs,
                globalMax: globalMax.blobs
            )
        case .blobsSmall:
            FeatureFormEditor(
                title: tab.title,
                minFeature: $minFeatures.nested(\.blobsSmall),
                maxFeature: $maxFeatures.nested(\.blobsSmall),
                globalMin: globalMin.blobsSmall,
                globalMax: globalMax.blobsSmall
            )
        case .substance:
            FeatureFormEditor(
                title: tab.title,
                minFeature: $minFeatures.nested(\.substance),
                maxFeature: $maxFeatures.nested(\.substance),
                globalMin: globalMin.substance,
                globalMax: globalMax.substance
            )
        }
    }
}

// MARK: - Caves

private enum CaveTab: String, CaseIterable, Identifiable {
    case mouth, tunnel

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mouth: "Mouth"
        case .tunnel: "Tunnel"
        }
    }
}

struct CavesTabbedEditor: View {
    @Binding var minCaves: Caves
    @Binding var maxCaves: Caves
    let globalMin: Caves
    let globalMax: Caves

    @State private var selectedTab: CaveTab = .mouth

    var body: some View {
        VStack(spacing: 0) {
            Picker("Cave", selection: $selectedTab) {
                ForEach(CaveTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            caveEditor(for: selectedTab)
        }
    }

    @ViewBuilder
    private func caveEditor(for tab: CaveTab) -> some View {
        switch tab {
        case .mouth:
            FeatureFormEditor(
                title: "Underground Mouth",
                minFeature: $minCaves.nested(\.underground).nested(\.mouth),
                maxFeature: $maxCaves.nested(\.underground).nested(\.mouth),
                globalMin: globalMin.underground.mouth,
                globalMax: globalMax.underground.mouth
            )
        case .tunnel:
            FeatureFormEditor(
                title: "Underground Tunnel",
                minFeature: $minCaves.nested(\.underground).nested(\.tunnel),
                maxFeature: $maxCaves.nested(\.underground).nested(\.tunnel),
                globalMin: globalMin.underground.tunnel,
                globalMax: globalMax.underground.tunnel
            )
        }
    }
}
