import SwiftUI

/// The time ruler, drawn tile by tile like the waveform.
///
/// Dragging it scrubs. The ruler is the scrub surface rather than the whole
/// timeline so that a finger dragged across the waveform still scrolls, which
/// is what a finger expects to do.
struct TimelineRulerLane: View {
    let geometry: TimelineGeometry
    let tiles: [TimelineTile]
    var height: CGFloat = 30

    var body: some View {
        LazyHStack(spacing: 0) {
            ForEach(tiles) { tile in
                RulerTileView(geometry: geometry, tile: tile, height: height)
                    .frame(width: tile.width, height: height)
            }
        }
        .frame(height: height)
        .accessibilityLabel("Règle temporelle")
        .accessibilityValue("Durée totale \(AppFormat.preciseTimecode(geometry.duration))")
    }
}

private struct RulerTileView: View {
    let geometry: TimelineGeometry
    let tile: TimelineTile
    let height: CGFloat

    private var ticks: [TimeInterval] {
        geometry.rulerTicks(in: tile.timeRange)
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Canvas { context, size in
                var path = Path()
                for tick in ticks {
                    let x = geometry.x(for: tick) - geometry.x(for: tile.startTime)
                    guard x >= -1, x <= size.width + 1 else { continue }
                    path.move(to: CGPoint(x: x, y: size.height - 8))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                }
                context.stroke(path, with: .color(Color.secondary.opacity(0.45)), lineWidth: 1)
            }

            ForEach(ticks, id: \.self) { tick in
                Text(AppFormat.timecode(tick))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .fixedSize()
                    .offset(x: geometry.x(for: tick) - geometry.x(for: tile.startTime) + 3, y: -10)
            }
        }
        .frame(height: height, alignment: .bottomLeading)
        .clipped()
    }
}
