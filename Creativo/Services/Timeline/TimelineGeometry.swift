import Foundation
import CoreGraphics

/// The timeline's coordinate system: one place that converts seconds to points
/// and back.
///
/// Every view, gesture and hit test goes through this. Having a single
/// conversion is what keeps the playhead, the ruler, the sections and the
/// markers aligned at any zoom, and it makes the whole thing testable without
/// a window.
struct TimelineGeometry: Equatable, Sendable {
    /// Length of the track, in seconds.
    var duration: TimeInterval
    /// Horizontal scale. This is the zoom: nothing vertical ever changes.
    var pixelsPerSecond: CGFloat

    static let minimumPixelsPerSecond: CGFloat = 1
    static let maximumPixelsPerSecond: CGFloat = 800

    init(duration: TimeInterval, pixelsPerSecond: CGFloat) {
        self.duration = max(duration, 0)
        self.pixelsPerSecond = min(max(pixelsPerSecond, Self.minimumPixelsPerSecond), Self.maximumPixelsPerSecond)
    }

    /// Width of the whole track at the current zoom.
    var contentWidth: CGFloat {
        max(CGFloat(duration) * pixelsPerSecond, 1)
    }

    func x(for time: TimeInterval) -> CGFloat {
        CGFloat(clampedTime(time)) * pixelsPerSecond
    }

    func time(forX x: CGFloat) -> TimeInterval {
        guard pixelsPerSecond > 0 else { return 0 }
        return clampedTime(TimeInterval(x / pixelsPerSecond))
    }

    func width(forDuration value: TimeInterval) -> CGFloat {
        max(CGFloat(max(value, 0)) * pixelsPerSecond, 0)
    }

    func clampedTime(_ time: TimeInterval) -> TimeInterval {
        guard duration > 0 else { return max(time, 0) }
        return min(max(time, 0), duration)
    }

    /// Zoom that shows the whole track in the space available.
    static func fittingPixelsPerSecond(duration: TimeInterval, availableWidth: CGFloat) -> CGFloat {
        guard duration > 0, availableWidth > 0 else { return 60 }
        return min(
            max(availableWidth / CGFloat(duration), minimumPixelsPerSecond),
            maximumPixelsPerSecond
        )
    }

    /// Applies a pinch or a zoom command, keeping the result inside the bounds.
    func zoomed(by factor: CGFloat) -> TimelineGeometry {
        TimelineGeometry(duration: duration, pixelsPerSecond: pixelsPerSecond * factor)
    }

    /// Scroll offset that keeps `time` at the same place on screen after a
    /// zoom change. This is what makes zooming feel anchored rather than
    /// teleporting.
    func scrollOffset(keeping time: TimeInterval, atViewportX anchorX: CGFloat, viewportWidth: CGFloat) -> CGFloat {
        let target = x(for: time) - anchorX
        let maximum = max(contentWidth - viewportWidth, 0)
        return min(max(target, 0), maximum)
    }

    /// Time range currently on screen, used to draw only the visible waveform.
    func visibleRange(scrollOffset: CGFloat, viewportWidth: CGFloat) -> ClosedRange<TimeInterval> {
        guard duration > 0, viewportWidth > 0 else { return 0...0 }
        let start = time(forX: max(scrollOffset, 0))
        let end = time(forX: max(scrollOffset, 0) + viewportWidth)
        guard end > start else { return start...(start + 0.001) }
        return start...end
    }

    /// Spacing between ruler ticks, chosen so labels never collide.
    var rulerStep: TimeInterval {
        let candidates: [TimeInterval] = [0.5, 1, 2, 5, 10, 15, 30, 60, 120, 300, 600]
        let minimumSpacing: CGFloat = 76
        for candidate in candidates where width(forDuration: candidate) >= minimumSpacing {
            return candidate
        }
        return candidates.last ?? 60
    }

    /// Tick times to draw for the visible range, including one on each side so
    /// labels do not pop in at the edges.
    func rulerTicks(in range: ClosedRange<TimeInterval>) -> [TimeInterval] {
        let step = rulerStep
        guard step > 0, duration > 0 else { return [] }
        let first = (range.lowerBound / step).rounded(.down) * step
        var ticks: [TimeInterval] = []
        var value = max(first, 0)
        while value <= min(range.upperBound + step, duration) {
            ticks.append(value)
            value += step
        }
        return ticks
    }
}
