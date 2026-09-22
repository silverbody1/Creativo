import SwiftUI

/// The waveform, drawn tile by tile.
///
/// Each tile asks the extracted samples for just its own slice, reduced to the
/// columns it has room for. Nothing re-reads the audio file, and a tile off
/// screen costs nothing at all.
struct WaveformLane: View {
    let samples: WaveformSamples
    let geometry: TimelineGeometry
    let tiles: [TimelineTile]
    var height: CGFloat = 132
    var tint: Color = .teal
    var isPlaceholder: Bool = false

    var body: some View {
        LazyHStack(spacing: 0) {
            ForEach(tiles) { tile in
                WaveformTileView(
                    samples: samples,
                    tile: tile,
                    height: height,
                    tint: tint,
                    isPlaceholder: isPlaceholder
                )
                .frame(width: tile.width, height: height)
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// One tile of waveform.
private struct WaveformTileView: View {
    let samples: WaveformSamples
    let tile: TimelineTile
    let height: CGFloat
    let tint: Color
    let isPlaceholder: Bool

    /// Two points per column keeps the shape readable without drawing a bar
    /// for every pixel.
    private var columnCount: Int {
        max(Int(tile.width / 2), 1)
    }

    var body: some View {
        Canvas(opaque: false, rendersAsynchronously: false) { context, size in
            let peaks = samples.peaks(in: tile.timeRange, targetCount: columnCount)
            guard !peaks.isEmpty else { return }

            let middle = size.height / 2
            let columnWidth = size.width / CGFloat(peaks.count)
            let barWidth = max(columnWidth * 0.62, 0.8)

            var path = Path()
            for (index, peak) in peaks.enumerated() {
                let amplitude = max(CGFloat(peak) * (size.height / 2 - 2), 0.6)
                let x = CGFloat(index) * columnWidth + (columnWidth - barWidth) / 2
                path.addRoundedRect(
                    in: CGRect(x: x, y: middle - amplitude, width: barWidth, height: amplitude * 2),
                    cornerSize: CGSize(width: barWidth / 2, height: barWidth / 2)
                )
            }
            context.fill(path, with: .color(tint.opacity(isPlaceholder ? 0.28 : 0.85)))
        }
    }
}

#Preview {
    let samples = WaveformSamples.placeholder(duration: 180)
    let geometry = TimelineGeometry(duration: 180, pixelsPerSecond: 8)
    ScrollView(.horizontal) {
        WaveformLane(
            samples: samples,
            geometry: geometry,
            tiles: TimelineTiling.tiles(for: geometry),
            isPlaceholder: true
        )
        .frame(width: geometry.contentWidth)
    }
    .frame(height: 160)
}
