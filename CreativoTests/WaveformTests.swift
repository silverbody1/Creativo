import XCTest
@testable import Creativo

/// The level-of-detail arithmetic, tested without touching a file.
final class WaveformSamplesTests: XCTestCase {
    private let samples = WaveformSamples(
        peaks: [0.1, 0.9, 0.2, 0.3, 0.8, 0.4, 0.5, 0.6],
        duration: 8
    )

    func testSecondsPerPeakFollowsTheResolution() {
        XCTAssertEqual(samples.secondsPerPeak, 1, accuracy: 0.0001)
        XCTAssertEqual(WaveformSamples.empty.secondsPerPeak, 0)
    }

    func testAskingForTheWholeTrackReturnsEverything() {
        let peaks = samples.peaks(in: 0...8, targetCount: 8)
        XCTAssertEqual(peaks.count, 8)
        XCTAssertEqual(peaks, samples.peaks)
    }

    func testZoomingOutMaxPoolsRatherThanAveraging() {
        // A transient that survives zooming out is the point of max pooling.
        let peaks = samples.peaks(in: 0...8, targetCount: 4)
        XCTAssertEqual(peaks.count, 4)
        XCTAssertEqual(peaks[0], 0.9, accuracy: 0.0001)
        XCTAssertEqual(peaks[1], 0.3, accuracy: 0.0001)
        XCTAssertEqual(peaks[2], 0.8, accuracy: 0.0001)
        XCTAssertEqual(peaks[3], 0.6, accuracy: 0.0001)
    }

    func testZoomingInReadsOnlyTheVisibleSlice() {
        let peaks = samples.peaks(in: 4...6, targetCount: 2)
        XCTAssertEqual(peaks.count, 2)
        XCTAssertEqual(peaks[0], 0.8, accuracy: 0.0001)
        XCTAssertEqual(peaks[1], 0.4, accuracy: 0.0001)
    }

    func testAskingForMoreColumnsThanStoredNeverCrashes() {
        let peaks = samples.peaks(in: 0...1, targetCount: 40)
        XCTAssertEqual(peaks.count, 40)
        XCTAssertTrue(peaks.allSatisfy { $0 >= 0 && $0 <= 1 })
    }

    func testRangesOutsideTheTrackAreHandled() {
        XCTAssertTrue(samples.peaks(in: 20...30, targetCount: 4).isEmpty)
        XCTAssertFalse(samples.peaks(in: -10...4, targetCount: 4).isEmpty)
        XCTAssertTrue(samples.peaks(in: 0...8, targetCount: 0).isEmpty)
        XCTAssertTrue(WaveformSamples.empty.peaks(in: 0...8, targetCount: 4).isEmpty)
    }

    func testPlaceholderIsDeterministicAndNormalised() {
        let first = WaveformSamples.placeholder(duration: 120, bucketCount: 200)
        let second = WaveformSamples.placeholder(duration: 120, bucketCount: 200)
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.peaks.count, 200)
        XCTAssertEqual(first.duration, 120)
        XCTAssertTrue(first.peaks.allSatisfy { $0 >= 0 && $0 <= 1 })
        XCTAssertTrue(WaveformSamples.placeholder(duration: 0).isEmpty)
    }

    func testEncodingRoundTripsThroughTheCacheFormat() throws {
        let data = try JSONEncoder().encode(samples)
        let decoded = try JSONDecoder().decode(WaveformSamples.self, from: data)
        XCTAssertEqual(decoded, samples)
    }
}

/// The on-disk cache, exercised on a throwaway identifier.
final class WaveformCacheTests: XCTestCase {
    private let identifier = UUID()

    override func tearDown() {
        WaveformCache.remove(assetID: identifier)
        super.tearDown()
    }

    func testSavedWaveformComesBackIdentical() throws {
        let samples = WaveformSamples(peaks: [0.2, 0.4, 0.9], duration: 3)
        WaveformCache.save(samples, assetID: identifier)

        let loaded = try XCTUnwrap(WaveformCache.load(assetID: identifier))
        XCTAssertEqual(loaded, samples)
    }

    func testAnEmptyWaveformIsNeverCached() {
        WaveformCache.save(.empty, assetID: identifier)
        XCTAssertNil(WaveformCache.load(assetID: identifier))
    }

    func testACorruptCacheIsDiscardedRatherThanFatal() throws {
        try FileManager.default.createDirectory(at: WaveformCache.rootURL, withIntermediateDirectories: true)
        try Data("pas du json".utf8).write(to: WaveformCache.url(assetID: identifier))

        XCTAssertNil(WaveformCache.load(assetID: identifier))
        XCTAssertFalse(FileManager.default.fileExists(atPath: WaveformCache.url(assetID: identifier).path(percentEncoded: false)))
    }

    func testAnUnknownIdentifierSimplyHasNoCache() {
        XCTAssertNil(WaveformCache.load(assetID: UUID()))
    }
}
