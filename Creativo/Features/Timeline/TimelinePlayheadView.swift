import SwiftUI

/// The playhead, and the handle used to drag it.
///
/// It is its own view for one reason: it is the only thing that reads
/// `currentTime`. A tick therefore redraws a one-point line and a small
/// triangle, not the timeline.
struct TimelinePlayheadView: View {
    let playback: AudioPlaybackController
    let geometry: TimelineGeometry
    var height: CGFloat
    /// Times the playhead should magnetise to while being dragged.
    var makeSnapper: () -> TimelineSnapper = { .disabled }
    /// Called once per second of playback, so the timeline can follow along
    /// without observing every tick itself.
    var onSecondChanged: ((TimeInterval) -> Void)?

    /// Position when the drag began. Translation is used rather than absolute
    /// location so the gesture needs no named coordinate space.
    @State private var dragOrigin: TimeInterval?

    var body: some View {
        let x = geometry.x(for: playback.currentTime)

        ZStack(alignment: .top) {
            Rectangle()
                .fill(Color.accentColor)
                .frame(width: 1.5, height: height)
                .allowsHitTesting(false)

            handle
        }
        .frame(width: 22, height: height, alignment: .top)
        .offset(x: x - 11)
        .onChange(of: Int(playback.currentTime)) { _, second in
            onSecondChanged?(TimeInterval(second))
        }
    }

    /// The only hit-testable part: the line itself stays transparent to clicks
    /// so the waveform and the sections underneath remain reachable.
    private var handle: some View {
        Triangle()
            .fill(Color.accentColor)
            .frame(width: 13, height: 8)
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let origin = dragOrigin ?? playback.currentTime
                        dragOrigin = origin
                        let raw = geometry.time(forX: geometry.x(for: origin) + value.translation.width)
                        playback.seek(to: makeSnapper().snap(raw))
                    }
                    .onEnded { _ in dragOrigin = nil }
            )
            .accessibilityLabel("Tête de lecture")
            .accessibilityValue(AppFormat.preciseTimecode(playback.currentTime))
            .accessibilityHint("Glissez pour déplacer la tête de lecture")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: playback.skip(by: PlaybackMath.coarseStep)
                case .decrement: playback.skip(by: -PlaybackMath.coarseStep)
                @unknown default: break
                }
            }
    }
}

/// Downward triangle used for the playhead handle.
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
