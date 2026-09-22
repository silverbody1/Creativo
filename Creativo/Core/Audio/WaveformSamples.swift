import Foundation

/// A downsampled amplitude envelope of an audio file.
///
/// Extraction happens once at a high resolution; zooming never re-reads the
/// file. The view asks for the slice it needs through `peaks(in:targetCount:)`,
/// which max-pools the stored buckets down to the pixels available. That is
/// the whole level-of-detail story, and it is pure arithmetic.
struct WaveformSamples: Codable, Equatable, Sendable {
    /// Normalised peaks, 0 to 1, evenly spaced over the whole file.
    let peaks: [Float]
    let duration: TimeInterval

    init(peaks: [Float], duration: TimeInterval) {
        self.peaks = peaks
        self.duration = duration
    }

    static let empty = WaveformSamples(peaks: [], duration: 0)

    var isEmpty: Bool { peaks.isEmpty || duration <= 0 }

    /// Seconds covered by one stored bucket.
    var secondsPerPeak: TimeInterval {
        guard !isEmpty else { return 0 }
        return duration / Double(peaks.count)
    }

    /// Peaks for a visible time range, reduced to `targetCount` columns.
    ///
    /// Max-pooling rather than averaging: a transient that disappears when you
    /// zoom out is exactly the transient someone is looking for.
    func peaks(in range: ClosedRange<TimeInterval>, targetCount: Int) -> [Float] {
        guard !isEmpty, targetCount > 0 else { return [] }

        let lower = max(range.lowerBound, 0)
        let upper = min(range.upperBound, duration)
        guard upper > lower else { return [] }

        let perPeak = secondsPerPeak
        guard perPeak > 0 else { return [] }

        let startIndex = min(max(Int(lower / perPeak), 0), peaks.count - 1)
        let endIndex = min(max(Int((upper / perPeak).rounded(.up)), startIndex + 1), peaks.count)
        let available = endIndex - startIndex

        var result: [Float] = []
        result.reserveCapacity(targetCount)
        for column in 0..<targetCount {
            let from = startIndex + available * column / targetCount
            let rawTo = startIndex + available * (column + 1) / targetCount
            let to = min(max(rawTo, from + 1), endIndex)
            var maximum: Float = 0
            for index in from..<to {
                maximum = max(maximum, peaks[index])
            }
            result.append(maximum)
        }
        return result
    }

    /// Deterministic stand-in used by previews and by the "no audio yet" state.
    ///
    /// Explicitly not a fake waveform for a real file: it is only ever built
    /// when there is no file to read.
    static func placeholder(duration: TimeInterval, bucketCount: Int = 900) -> WaveformSamples {
        guard duration > 0, bucketCount > 0 else { return .empty }
        let peaks = (0..<bucketCount).map { index -> Float in
            let position = Double(index) / Double(bucketCount)
            let body = 0.35 + 0.30 * sin(position * .pi * 9)
            let pulse = 0.20 * sin(position * .pi * 47)
            let fade = min(position * 8, 1) * min((1 - position) * 8, 1)
            return Float(max(0.05, (body + pulse) * fade))
        }
        return WaveformSamples(peaks: peaks, duration: duration)
    }
}
