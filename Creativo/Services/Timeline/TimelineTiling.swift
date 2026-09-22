import Foundation
import CoreGraphics

/// One slice of the timeline, drawn independently of the others.
struct TimelineTile: Identifiable, Equatable, Sendable {
    let id: Int
    let startTime: TimeInterval
    let endTime: TimeInterval
    let width: CGFloat

    var timeRange: ClosedRange<TimeInterval> {
        endTime > startTime ? startTime...endTime : startTime...(startTime + 0.001)
    }
}

/// Cuts the track into fixed-width tiles.
///
/// A three-minute track zoomed all the way in is over a hundred thousand
/// points wide. Drawing that as one canvas is not an option, so the waveform
/// and the ruler are drawn as tiles inside a lazy stack: only the ones on
/// screen are ever built, and zooming never rebuilds the rest.
enum TimelineTiling {
    static let tileWidth: CGFloat = 480

    static func tiles(for geometry: TimelineGeometry) -> [TimelineTile] {
        guard geometry.duration > 0, geometry.pixelsPerSecond > 0 else { return [] }

        let total = geometry.contentWidth
        let count = max(Int((total / tileWidth).rounded(.up)), 1)
        let secondsPerTile = TimeInterval(tileWidth / geometry.pixelsPerSecond)

        return (0..<count).map { index in
            let start = TimeInterval(index) * secondsPerTile
            let end = min(start + secondsPerTile, geometry.duration)
            let width = min(tileWidth, total - CGFloat(index) * tileWidth)
            return TimelineTile(id: index, startTime: start, endTime: end, width: max(width, 1))
        }
    }
}
