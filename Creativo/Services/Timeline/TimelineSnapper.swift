import Foundation
import CoreGraphics

/// Magnetism between a dragged time and the points that matter.
///
/// Tolerance is expressed in seconds but derived from the zoom by the caller,
/// so the magnet always feels like the same number of points on screen no
/// matter how far in the timeline is zoomed.
struct TimelineSnapper: Equatable, Sendable {
    /// Times worth snapping to: the playhead, section edges, markers.
    var candidates: [TimeInterval]
    var tolerance: TimeInterval
    var isEnabled: Bool

    init(candidates: [TimeInterval], tolerance: TimeInterval, isEnabled: Bool = true) {
        self.candidates = candidates
        self.tolerance = max(tolerance, 0)
        self.isEnabled = isEnabled
    }

    static let disabled = TimelineSnapper(candidates: [], tolerance: 0, isEnabled: false)

    /// The nearest candidate within tolerance, or the time untouched.
    func snap(_ time: TimeInterval) -> TimeInterval {
        result(for: time).time
    }

    /// Same, but says whether it snapped, so the interface can show the guide.
    func result(for time: TimeInterval) -> (time: TimeInterval, target: TimeInterval?) {
        guard isEnabled, tolerance > 0, !candidates.isEmpty else { return (time, nil) }

        var best: TimeInterval?
        var bestDistance = TimeInterval.greatestFiniteMagnitude
        for candidate in candidates {
            let distance = abs(candidate - time)
            if distance < bestDistance {
                bestDistance = distance
                best = candidate
            }
        }
        guard let best, bestDistance <= tolerance else { return (time, nil) }
        return (best, best)
    }

    /// Points of magnetism, in points on screen, turned into seconds.
    static func tolerance(forPixels pixels: CGFloat, pixelsPerSecond: CGFloat) -> TimeInterval {
        guard pixelsPerSecond > 0 else { return 0 }
        return TimeInterval(pixels / pixelsPerSecond)
    }
}
