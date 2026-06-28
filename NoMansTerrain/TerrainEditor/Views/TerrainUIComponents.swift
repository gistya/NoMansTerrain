import NoMansTerrainCore
import SwiftUI

// MARK: - Platform Modifiers

extension View {
    @ViewBuilder
    func terrainScrollEdgeEffect() -> some View {
        if #available(iOS 26, macOS 26, *) {
            scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            self
        }
    }

    @ViewBuilder
    func terrainFormPresentationSizing() -> some View {
        if #available(iOS 18, macOS 15, *) {
            presentationSizing(.form)
        } else {
            self
        }
    }
}

// MARK: - Chip Picker

struct TerrainChipOption<ID: Hashable>: Identifiable {
    let id: ID
    let title: String
    var systemImage: String?
}

struct TerrainChipPicker<ID: Hashable>: View {
    let options: [TerrainChipOption<ID>]
    @Binding var selection: ID

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(options) { option in
                    chipButton(for: option)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }

    private func chipButton(for option: TerrainChipOption<ID>) -> some View {
        let isSelected = selection == option.id

        return Button {
            selection = option.id
        } label: {
            chipLabel(for: option)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor.opacity(0.18) : Color.clear, in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(isSelected ? Color.accentColor : Color.secondary.opacity(0.35), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
        .contentShape(Capsule())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func chipLabel(for option: TerrainChipOption<ID>) -> some View {
        if let systemImage = option.systemImage {
            Label(option.title, systemImage: systemImage)
                .font(.subheadline)
                .labelStyle(.titleAndIcon)
        } else {
            Text(option.title)
                .font(.subheadline)
        }
    }
}

// MARK: - Loading Overlay

struct TerrainLoadingOverlay: View {
    let message: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.15)
                .ignoresSafeArea()
            ProgressView(message)
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Sidebar Row

struct TerrainSidebarRow: View {
    let title: String
    let subtitle: String
    var systemImage: String?

    var body: some View {
        HStack {
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
            }
            VStack(alignment: .leading) {
                Text(title)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
    }
}