import SwiftUI

/// One line of the scene list.
struct SceneRow: View {
    let scene: StoryScene

    var body: some View {
        HStack(spacing: Spacing.md) {
            Text(scene.displayNumber)
                .font(.callout.monospacedDigit().weight(.semibold))
                .foregroundStyle(scene.status.tint)
                .frame(minWidth: 34, minHeight: 34)
                .background(scene.status.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(scene.displayTitle)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                HStack(spacing: Spacing.sm) {
                    Text(scene.environment.abbreviation)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(scene.timeOfDay.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let location = scene.location {
                        Text("· \(location.displayName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    if scene.estimatedDuration > 0 {
                        Text("· \(AppFormat.timecode(scene.estimatedDuration))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: Spacing.sm)

            if !scene.shots.isEmpty {
                let progress = scene.shotProgress
                Text("\(progress.completed)/\(progress.total)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .help("Plans tournés")
            }

            StatusDot(text: scene.status.displayName, tint: scene.status.tint)
        }
        .touchTarget()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Scène \(scene.displayNumber), \(scene.displayTitle), \(scene.environment.displayName), \(scene.timeOfDay.displayName)")
    }
}

#Preview {
    List {
        SceneRow(scene: StoryScene(sceneNumber: "1", title: "Intro", environment: .interior, timeOfDay: .night, estimatedDuration: 42))
        SceneRow(scene: StoryScene(sceneNumber: "2", title: "Refrain 1", environment: .exterior, timeOfDay: .goldenHour, estimatedDuration: 58, status: .locked))
    }
}
