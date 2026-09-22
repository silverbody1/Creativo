import Foundation
import AVFoundation
import OSLog

/// Reads an audio file and reduces it to an amplitude envelope.
///
/// `AVAudioFile` is used rather than `AVAssetReader` on purpose: it decodes
/// WAV, AIFF, MP3 and AAC to the same float format, which keeps the whole
/// extractor to one loop with no format branching.
enum WaveformExtractor {
    /// Buckets extracted per file. At three minutes this is one bucket every
    /// 30 ms, fine enough to zoom into a snare hit and small enough to cache.
    static let defaultBucketCount = 6_000

    private static let logger = Logger(subsystem: "com.creativo.studio", category: "waveform")

    enum Failure: LocalizedError {
        case unreadable(String)
        case empty

        var errorDescription: String? {
            switch self {
            case .unreadable(let reason): return "Fichier audio illisible : \(reason)"
            case .empty: return "Le fichier audio ne contient aucun son."
            }
        }
    }

    /// Blocking work: call it off the main actor.
    static func extract(from url: URL, bucketCount: Int = defaultBucketCount) throws -> WaveformSamples {
        guard bucketCount > 0 else { return .empty }

        let file: AVAudioFile
        do {
            file = try AVAudioFile(forReading: url)
        } catch {
            throw Failure.unreadable(error.localizedDescription)
        }

        let format = file.processingFormat
        let totalFrames = file.length
        guard totalFrames > 0, format.sampleRate > 0 else { throw Failure.empty }

        let duration = Double(totalFrames) / format.sampleRate
        let framesPerBucket = max(Int(totalFrames) / bucketCount, 1)
        let chunkFrames = AVAudioFrameCount(min(max(framesPerBucket * 8, 8_192), 262_144))

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunkFrames) else {
            throw Failure.unreadable("mémoire insuffisante")
        }

        var peaks: [Float] = []
        peaks.reserveCapacity(bucketCount)
        var bucketMaximum: Float = 0
        var framesInBucket = 0

        while file.framePosition < totalFrames && peaks.count < bucketCount {
            do {
                try file.read(into: buffer)
            } catch {
                throw Failure.unreadable(error.localizedDescription)
            }
            let frames = Int(buffer.frameLength)
            guard frames > 0, let channels = buffer.floatChannelData else { break }
            let channelCount = Int(buffer.format.channelCount)

            for frame in 0..<frames {
                var value: Float = 0
                for channel in 0..<channelCount {
                    value = max(value, abs(channels[channel][frame]))
                }
                bucketMaximum = max(bucketMaximum, value)
                framesInBucket += 1

                if framesInBucket >= framesPerBucket {
                    peaks.append(min(bucketMaximum, 1))
                    bucketMaximum = 0
                    framesInBucket = 0
                    if peaks.count >= bucketCount { break }
                }
            }
        }

        if framesInBucket > 0 && peaks.count < bucketCount {
            peaks.append(min(bucketMaximum, 1))
        }

        guard !peaks.isEmpty else { throw Failure.empty }
        logger.debug("Waveform extraite: \(peaks.count) points pour \(duration) s")
        return WaveformSamples(peaks: peaks, duration: duration)
    }

    /// Duration and sample rate without decoding the whole file.
    static func probe(url: URL) -> (duration: TimeInterval, sampleRate: Double)? {
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let rate = file.processingFormat.sampleRate
        guard rate > 0 else { return nil }
        return (Double(file.length) / rate, file.fileFormat.sampleRate)
    }
}
