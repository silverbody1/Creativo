import SwiftUI

/// Markers: the instants worth remembering that are not sections.
///
/// A drum entry or a lyric hit is a point, not a unit of the breakdown, so it
/// never becomes a scene. Tapping one moves the playhead to it.
struct TimelineMarkersLane: View {
    let markers: [TimelineMarker]
    let geometry: TimelineGeometry
    /// See `TimelineSectionsLane`: built inside the gesture, never in the body.
    let makeSnapper: () -> TimelineSnapper
    var height: CGFloat = 34

    let onSelect: (TimelineMarker) -> Void
    let onEdit: (TimelineMarker) -> Void
    let onCommitMove: (TimelineMarker, TimeInterval) -> Void

    @State private var dragging: (id: UUID, time: TimeInterval)?

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color.clear)
                .frame(height: height)

            ForEach(markers) { marker in
                pin(for: marker)
            }
        }
        .frame(height: height, alignment: .topLeading)
    }

    private func pin(for marker: TimelineMarker) -> some View {
        let time = effectiveTime(of: marker)
        let tint = tint(for: marker.type)

        return Button {
            onSelect(marker)
        } label: {
            HStack(spacing: 3) {
                Text(marker.type.badge)
                    .font(.caption2.weight(.bold))
                Text(marker.displayTitle)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(tint.opacity(0.20), in: Capsule(style: .continuous))
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(tint)
                    .frame(width: 1.5, height: height)
                    .offset(y: 8)
            }
            .foregroundStyle(tint)
            .fixedSize()
        }
        .buttonStyle(.plain)
        .offset(x: geometry.x(for: time), y: 2)
        .contextMenu {
            Button("Modifier le marqueur") { onEdit(marker) }
            Button("Placer la tête de lecture ici") { onSelect(marker) }
        }
        .highPriorityGesture(
            DragGesture(minimumDistance: 3)
                .onChanged { value in
                    let raw = geometry.time(forX: geometry.x(for: marker.time) + value.translation.width)
                    dragging = (id: marker.id, time: makeSnapper().snap(raw))
                }
                .onEnded { _ in
                    if let dragging, dragging.id == marker.id {
                        onCommitMove(marker, dragging.time)
                    }
                    dragging = nil
                }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(marker.accessibilityDescription)
        .accessibilityHint("Déplace la tête de lecture sur ce repère")
    }

    private func effectiveTime(of marker: TimelineMarker) -> TimeInterval {
        if let dragging, dragging.id == marker.id { return dragging.time }
        return marker.time
    }

    private func tint(for type: TimelineMarkerType) -> Color {
        switch type {
        case .standard: return .blue
        case .beat: return .orange
        case .lyric: return .purple
        case .camera: return .teal
        case .note: return .yellow
        }
    }
}
