import SwiftUI

/// The structure of the song, read as a list.
///
/// The timeline shows proportions; this shows the shape. Both read the same
/// sections, and selecting one here moves the playhead there.
struct SongStructureView: View {
    let project: Project
    let selectedSceneID: UUID?
    let onSelect: (StoryScene) -> Void

    private var sections: [StoryScene] { project.timedSections }
    private var unplaced: [StoryScene] {
        project.musicSections.filter { $0.musicFacet?.startTime == nil }
    }

    var body: some View {
        List {
            Section {
                if sections.isEmpty {
                    Text("Aucune section placée sur le morceau.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sections) { scene in
                        Button {
                            onSelect(scene)
                        } label: {
                            row(for: scene)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(
                            scene.id == selectedSceneID ? Color.accentColor.opacity(0.12) : Color.clear
                        )
                    }
                }
            } header: {
                Text("Structure")
                    .textCase(nil)
            }

            if !unplaced.isEmpty {
                Section {
                    ForEach(unplaced) { scene in
                        Button {
                            onSelect(scene)
                        } label: {
                            HStack(spacing: Spacing.sm) {
                                Text(scene.musicSectionName)
                                    .font(.callout)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                                Image(systemName: "questionmark.circle")
                                    .foregroundStyle(.tertiary)
                            }
                            .touchTarget(34)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Non placées")
                        .textCase(nil)
                } footer: {
                    Text("Placez la tête de lecture puis utilisez « Placer ici » dans l'inspecteur.")
                        .font(.caption)
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func row(for scene: StoryScene) -> some View {
        let facet = scene.musicFacet
        let start = facet?.startTime ?? 0
        let end = facet?.endTime

        return VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: Spacing.xs) {
                Text(facet?.displayName ?? scene.displayTitle)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                if !scene.title.isBlank, scene.title != facet?.displayName {
                    Text(scene.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if !scene.shots.isEmpty {
                    Text("\(scene.shots.count)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            }
            Text(rangeText(start: start, end: end))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func rangeText(start: TimeInterval, end: TimeInterval?) -> String {
        guard let end else { return AppFormat.timecode(start) }
        return "\(AppFormat.timecode(start)) – \(AppFormat.timecode(end))"
    }
}
