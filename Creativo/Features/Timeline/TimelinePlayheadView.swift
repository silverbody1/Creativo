import SwiftUI

/// The playhead.
///
/// It is its own view for one reason: it is the only thing that reads
/// `currentTime`. A tick therefore redraws a one-point line and nothing else,
/// which is what keeps thirty frames a second from rebuilding the timeline.
struct TimelinePlayheadView: View {
    let playback: AudioPlaybackController
    let geometry: TimelineGeometry
    var height: CGFloat
    /// Called once per second of playback, so the timeline can follow along
    /// without observing every tick itself.
    var onSecondChanged: ((TimeInterval) -> Void)?

    var body: some View {
        let x = geometry.x(for: playback.currentTime)

        ZStack(alignment: .top) {
            Rectangle()
                .fill(Color.accentColor)
                .frame(width: 1.5, height: height)

            Triangle()
                .fill(Color.accentColor)
                .frame(width: 11, height: 7)
                .offset(y: -1)
        }
        .frame(width: 11, height: height, alignment: .top)
        .offset(x: x - 5.5)
        .allowsHitTesting(false)
        .onChange(of: Int(playback.currentTime)) { _, second in
            onSecondChanged?(TimeInterval(second))
        }
        .accessibilityHidden(true)
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
