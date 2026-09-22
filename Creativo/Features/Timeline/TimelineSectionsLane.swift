import SwiftUI

/// The structure of the song, laid over the track.
///
/// Each block is a real `StoryScene` carrying its music facet: dragging a
/// frontier here changes the same two numbers the writing editor shows, and
/// the shots hanging off that scene follow along. There is no second copy of
/// the timing anywhere.
struct TimelineSectionsLane: View {
    let project: Project
    let geometry: TimelineGeometry
    let selectedSceneID: UUID?
    /// Built on demand, inside the gesture: reading the playhead while the
    /// body is being evaluated would redraw the lane thirty times a second.
    let makeSnapper: () -> TimelineSnapper
    var height: CGFloat = 56

    let onSelect: (StoryScene) -> Void
    /// Called once, when the frontier is released.
    let onCommitBoundary: (StoryScene?, StoryScene?, TimeInterval) -> Void

    @State private var dragging: BoundaryDrag?

    /// Live state of a frontier being dragged. It lives here and never in
    /// SwiftData: a drag must not write to the store sixty times a second.
    private struct BoundaryDrag: Equatable {
        let previousID: UUID?
        let nextID: UUID?
        var time: TimeInterval
    }

    private var sections: [StoryScene] { project.timedSections }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Surface.subtle)
                .frame(height: height)

            ForEach(sections) { scene in
                block(for: scene)
            }

            ForEach(sections) { scene in
                handle(after: scene)
            }
        }
        .frame(height: height, alignment: .topLeading)
    }

    // MARK: Blocks

    private func block(for scene: StoryScene) -> some View {
        let start = effectiveStart(of: scene)
        let end = effectiveEnd(of: scene)
        let width = max(geometry.width(forDuration: end - start), 2)
        let isSelected = scene.id == selectedSceneID
        let tint = tint(for: scene)

        return Button {
            onSelect(scene)
        } label: {
            VStack(alignment: .leading, spacing: 1) {
                Text(label(for: scene))
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(AppFormat.timecode(start))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 6)
            .frame(width: width, height: height - 10, alignment: .leading)
            .background(
                tint.opacity(isSelected ? 0.34 : 0.18),
                in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
            )
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(tint)
                    .frame(width: 3)
                    .clipShape(RoundedRectangle(cornerRadius: 1.5, style: .continuous))
            }
            .overlay {
                RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                    .strokeBorder(isSelected ? tint : Color.clear, lineWidth: 1.5)
            }
            .clipped()
        }
        .buttonStyle(.plain)
        .offset(x: geometry.x(for: start), y: 5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: scene, start: start, end: end))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: Frontier handles

    private func handle(after scene: StoryScene) -> some View {
        let time = effectiveEnd(of: scene)
        let next = adjacentNext(of: scene)

        let isDragging = dragging?.previousID == scene.id

        return ZStack {
            Color.clear
            Rectangle()
                .fill(Color.accentColor.opacity(isDragging ? 0.95 : 0.35))
                .frame(width: isDragging ? 2 : 1, height: height - 8)
        }
        .frame(width: 12, height: height)
        .contentShape(Rectangle())
        .offset(x: geometry.x(for: time) - 6)
        .highPriorityGesture(
            DragGesture(minimumDistance: 2)
                .onChanged { value in
                    let raw = geometry.time(forX: geometry.x(for: time) + value.translation.width)
                    dragging = BoundaryDrag(
                        previousID: scene.id,
                        nextID: next?.id,
                        time: makeSnapper().snap(raw)
                    )
                }
                .onEnded { _ in
                    if let dragging {
                        onCommitBoundary(scene, next, dragging.time)
                    }
                    dragging = nil
                }
        )
        .help("Glissez pour déplacer la frontière")
        .accessibilityLabel("Fin de \(label(for: scene)), \(AppFormat.preciseTimecode(time))")
    }

    // MARK: Helpers

    private func effectiveStart(of scene: StoryScene) -> TimeInterval {
        if let dragging, dragging.nextID == scene.id { return dragging.time }
        return scene.musicFacet?.startTime ?? 0
    }

    private func effectiveEnd(of scene: StoryScene) -> TimeInterval {
        if let dragging, dragging.previousID == scene.id { return dragging.time }
        return scene.musicFacet?.endTime ?? effectiveStart(of: scene)
    }

    /// The following section, only when the two actually touch. Two sections
    /// with a gap between them keep independent edges.
    private func adjacentNext(of scene: StoryScene) -> StoryScene? {
        guard let index = sections.firstIndex(where: { $0.id == scene.id }),
              index + 1 < sections.count
        else { return nil }
        let next = sections[index + 1]
        let end = scene.musicFacet?.endTime ?? 0
        let start = next.musicFacet?.startTime ?? 0
        return abs(start - end) < 0.05 ? next : nil
    }

    private func label(for scene: StoryScene) -> String {
        scene.musicFacet?.displayName ?? scene.displayTitle
    }

    private func tint(for scene: StoryScene) -> Color {
        guard let kind = scene.musicFacet?.kind else { return .gray }
        return kind.isAnchor ? .pink : .purple
    }

    private func accessibilityLabel(for scene: StoryScene, start: TimeInterval, end: TimeInterval) -> String {
        var parts = [label(for: scene)]
        if !scene.title.isBlank { parts.append(scene.title) }
        parts.append("de \(AppFormat.preciseTimecode(start)) à \(AppFormat.preciseTimecode(end))")
        if let mode = scene.musicFacet?.performanceMode { parts.append(mode.displayName) }
        if !scene.shots.isEmpty {
            parts.append(AppFormat.count(scene.shots.count, singular: "plan", plural: "plans", zero: ""))
        }
        return parts.joined(separator: ", ")
    }
}
