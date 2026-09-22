import CoreGraphics
import XCTest
@testable import Creativo

/// The coordinate system is pure arithmetic, so it is tested without a window.
final class TimelineGeometryTests: XCTestCase {
    private let geometry = TimelineGeometry(duration: 180, pixelsPerSecond: 10)

    func testTimeAndPositionAreInverses() {
        XCTAssertEqual(geometry.x(for: 0), 0)
        XCTAssertEqual(geometry.x(for: 12), 120)
        XCTAssertEqual(geometry.time(forX: 120), 12, accuracy: 0.0001)
        XCTAssertEqual(geometry.time(forX: geometry.x(for: 47.5)), 47.5, accuracy: 0.0001)
    }

    func testPositionsAreClampedToTheTrack() {
        XCTAssertEqual(geometry.x(for: -30), 0)
        XCTAssertEqual(geometry.x(for: 500), geometry.contentWidth)
        XCTAssertEqual(geometry.time(forX: -100), 0)
        XCTAssertEqual(geometry.time(forX: 99_999), 180)
    }

    func testContentWidthFollowsTheZoom() {
        XCTAssertEqual(geometry.contentWidth, 1_800)
        XCTAssertEqual(geometry.zoomed(by: 2).contentWidth, 3_600)
        XCTAssertEqual(geometry.width(forDuration: 30), 300)
        XCTAssertEqual(geometry.width(forDuration: -5), 0)
    }

    func testZoomStaysInsideItsBounds() {
        let tooFar = geometry.zoomed(by: 10_000)
        XCTAssertEqual(tooFar.pixelsPerSecond, TimelineGeometry.maximumPixelsPerSecond)

        let tooClose = geometry.zoomed(by: 0.000_01)
        XCTAssertEqual(tooClose.pixelsPerSecond, TimelineGeometry.minimumPixelsPerSecond)
    }

    func testFittingZoomShowsTheWholeTrack() {
        let scale = TimelineGeometry.fittingPixelsPerSecond(duration: 180, availableWidth: 900)
        let fitted = TimelineGeometry(duration: 180, pixelsPerSecond: scale)
        XCTAssertEqual(fitted.contentWidth, 900, accuracy: 0.001)
    }

    func testFittingZoomSurvivesAnEmptyTrack() {
        XCTAssertGreaterThan(TimelineGeometry.fittingPixelsPerSecond(duration: 0, availableWidth: 900), 0)
        XCTAssertGreaterThan(TimelineGeometry.fittingPixelsPerSecond(duration: 180, availableWidth: 0), 0)
    }

    func testAZeroLengthTrackNeverDividesByZero() {
        let empty = TimelineGeometry(duration: 0, pixelsPerSecond: 10)
        XCTAssertEqual(empty.x(for: 5), 50)
        XCTAssertEqual(empty.contentWidth, 1)
        XCTAssertTrue(empty.rulerTicks(in: 0...10).isEmpty)
    }

    func testRulerStepGrowsAsTheTimelineZoomsOut() {
        let wide = TimelineGeometry(duration: 600, pixelsPerSecond: 1)
        let tight = TimelineGeometry(duration: 600, pixelsPerSecond: 200)
        XCTAssertGreaterThan(wide.rulerStep, tight.rulerStep)
        XCTAssertGreaterThanOrEqual(tight.width(forDuration: tight.rulerStep), 76)
    }

    func testRulerTicksCoverTheVisibleRange() {
        let ticks = geometry.rulerTicks(in: 30...60)
        XCTAssertFalse(ticks.isEmpty)
        XCTAssertLessThanOrEqual(ticks.first ?? 0, 30)
        XCTAssertGreaterThanOrEqual(ticks.last ?? 0, 60)
        XCTAssertTrue(ticks.allSatisfy { $0 >= 0 && $0 <= 180 })
    }

    func testVisibleRangeFollowsTheScroll() {
        let range = geometry.visibleRange(scrollOffset: 300, viewportWidth: 600)
        XCTAssertEqual(range.lowerBound, 30, accuracy: 0.0001)
        XCTAssertEqual(range.upperBound, 90, accuracy: 0.0001)
    }

    func testScrollOffsetKeepsAMomentUnderThePointer() {
        let offset = geometry.scrollOffset(keeping: 90, atViewportX: 300, viewportWidth: 600)
        XCTAssertEqual(offset, 600, accuracy: 0.0001)

        // Never scrolls past either end.
        XCTAssertEqual(geometry.scrollOffset(keeping: 0, atViewportX: 300, viewportWidth: 600), 0)
        XCTAssertEqual(
            geometry.scrollOffset(keeping: 180, atViewportX: 0, viewportWidth: 600),
            geometry.contentWidth - 600,
            accuracy: 0.0001
        )
    }

    // MARK: Tiling

    func testTilesCoverTheWholeTrackWithoutOverlapping() {
        let tiles = TimelineTiling.tiles(for: geometry)
        XCTAssertFalse(tiles.isEmpty)
        XCTAssertEqual(tiles.first?.startTime, 0)
        XCTAssertEqual(tiles.last?.endTime ?? 0, 180, accuracy: 0.001)

        let total = tiles.reduce(CGFloat.zero) { $0 + $1.width }
        XCTAssertEqual(total, geometry.contentWidth, accuracy: 0.5)

        for (index, tile) in tiles.enumerated() where index > 0 {
            XCTAssertEqual(tile.startTime, tiles[index - 1].endTime, accuracy: 0.001)
        }
    }

    func testTilingOfAnEmptyTrackProducesNothing() {
        XCTAssertTrue(TimelineTiling.tiles(for: TimelineGeometry(duration: 0, pixelsPerSecond: 10)).isEmpty)
    }
}

final class TimelineSnapperTests: XCTestCase {
    private let snapper = TimelineSnapper(candidates: [0, 22, 70, 108], tolerance: 1)

    func testSnapsToTheNearestCandidateInsideTolerance() {
        XCTAssertEqual(snapper.snap(22.4), 22)
        XCTAssertEqual(snapper.snap(69.2), 70)
        XCTAssertEqual(snapper.snap(0.6), 0)
    }

    func testLeavesTimeAloneOutsideTolerance() {
        XCTAssertEqual(snapper.snap(40), 40)
        XCTAssertEqual(snapper.snap(23.5), 23.5)
    }

    func testDisabledSnapperNeverMoves() {
        let disabled = TimelineSnapper(candidates: [0, 22], tolerance: 5, isEnabled: false)
        XCTAssertEqual(disabled.snap(21.9), 21.9)
        XCTAssertEqual(TimelineSnapper.disabled.snap(3), 3)
    }

    func testResultReportsWhatItSnappedTo() {
        XCTAssertEqual(snapper.result(for: 22.3).target, 22)
        XCTAssertNil(snapper.result(for: 45).target)
    }

    func testToleranceShrinksAsTheTimelineZoomsIn() {
        let wide = TimelineSnapper.tolerance(forPixels: 8, pixelsPerSecond: 2)
        let tight = TimelineSnapper.tolerance(forPixels: 8, pixelsPerSecond: 200)
        XCTAssertEqual(wide, 4, accuracy: 0.0001)
        XCTAssertEqual(tight, 0.04, accuracy: 0.0001)
        XCTAssertEqual(TimelineSnapper.tolerance(forPixels: 8, pixelsPerSecond: 0), 0)
    }

    func testNoCandidatesMeansNoSnapping() {
        XCTAssertEqual(TimelineSnapper(candidates: [], tolerance: 10).snap(7), 7)
    }
}

final class PlaybackMathTests: XCTestCase {
    func testClampStaysInsideTheTrack() {
        XCTAssertEqual(PlaybackMath.clamp(-5, duration: 100), 0)
        XCTAssertEqual(PlaybackMath.clamp(150, duration: 100), 100)
        XCTAssertEqual(PlaybackMath.clamp(42, duration: 100), 42)
    }

    func testClampWithoutADurationOnlyForbidsNegativeTime() {
        XCTAssertEqual(PlaybackMath.clamp(-5, duration: 0), 0)
        XCTAssertEqual(PlaybackMath.clamp(500, duration: 0), 500)
    }

    func testSkippingStopsAtBothEnds() {
        XCTAssertEqual(PlaybackMath.skipped(from: 3, by: -5, duration: 100), 0)
        XCTAssertEqual(PlaybackMath.skipped(from: 98, by: 5, duration: 100), 100)
        XCTAssertEqual(PlaybackMath.skipped(from: 50, by: PlaybackMath.fineStep, duration: 100), 50 + 1.0 / 25.0, accuracy: 0.0001)
    }

    func testProgressIsANormalisedRatio() {
        XCTAssertEqual(PlaybackMath.progress(50, duration: 100), 0.5, accuracy: 0.0001)
        XCTAssertEqual(PlaybackMath.progress(0, duration: 0), 0)
        XCTAssertEqual(PlaybackMath.progress(150, duration: 100), 1)
        XCTAssertEqual(PlaybackMath.progress(-10, duration: 100), 0)
    }
}
