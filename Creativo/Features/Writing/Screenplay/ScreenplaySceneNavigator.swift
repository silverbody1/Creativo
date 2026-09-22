import SwiftUI

/// Scene list of the screenplay editor.
///
/// A screenplay is read as one continuous document, so the navigator scrolls
/// rather than filters: the writer keeps the context of what comes before and
/// after the scene they jump to.
struct ScreenplaySceneNavigator: View {
    let scenes: [StoryScene]
    @Binding var selectedSceneID: UUID?
    let onSelect: (StoryScene) -> Void
    let onAddScene: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selectedSceneID) {
                Section {
                    ForEach(scenes) { scene in
                        Button {
                            onSelect(scene)
                        } label: {
                            row(for: scene)
                        }
                        .buttonStyle(.plain)
                        .tag(scene.id)
                    }
                } header: {
                    Text(AppFormat.count(scenes.count, singular: "scène", plural: "scènes", zero: "Aucune scène"))
                        .textCase(nil)
                }
            }
            .listStyle(.sidebar)

            Divider()

            Button(action: onAddScene) {
                Label("Nouvelle scène", systemImage: "plus")
                    .font(.callout)
                    .frame(maxWidth: .infinity)
                    .touchTarget(38)
            }
            .buttonStyle(.borderless)
            .padding(Spacing.sm)
        }
        .frame(width: 216)
    }

    private func row(for scene: StoryScene) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack(spacing: Spacing.xs) {
                Text(scene.displayNumber)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(scene.status.tint)
                Text(scene.displayTitle)
                    .font(.callout)
                    .lineLimit(1)
            }
            HStack(spacing: Spacing.xs) {
                Text(scene.environment.abbreviation)
                Text(scene.timeOfDay.displayName)
                if scene.hasScreenplay {
                    Text("· \(ScreenplayFormatter.pageCountText(for: [scene]))")
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .padding(.vertical, Spacing.xxs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}
