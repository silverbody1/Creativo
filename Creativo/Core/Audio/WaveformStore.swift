import Foundation
import OSLog

/// Caches waveforms in memory and on disk, and never extracts the same file twice.
actor WaveformStore {
    static let shared = WaveformStore()

    private var memory: [UUID: WaveformSamples] = [:]
    private var inFlight: [UUID: Task<WaveformSamples, Error>] = [:]
    private let logger = Logger(subsystem: "com.creativo.studio", category: "waveform")

    /// Waveform for an asset, extracting it only if neither cache has it.
    func waveform(
        assetID: UUID,
        url: URL,
        bucketCount: Int = WaveformExtractor.defaultBucketCount
    ) async throws -> WaveformSamples {
        if let cached = memory[assetID] { return cached }

        if let stored = WaveformCache.load(assetID: assetID) {
            memory[assetID] = stored
            return stored
        }

        if let running = inFlight[assetID] {
            return try await running.value
        }

        let task = Task.detached(priority: .userInitiated) {
            try WaveformExtractor.extract(from: url, bucketCount: bucketCount)
        }
        inFlight[assetID] = task

        do {
            let samples = try await task.value
            inFlight[assetID] = nil
            memory[assetID] = samples
            WaveformCache.save(samples, assetID: assetID)
            return samples
        } catch {
            inFlight[assetID] = nil
            logger.error("Extraction impossible: \(String(describing: error))")
            throw error
        }
    }

    /// Called when a track is replaced or removed.
    func invalidate(assetID: UUID) {
        memory[assetID] = nil
        inFlight[assetID]?.cancel()
        inFlight[assetID] = nil
        WaveformCache.remove(assetID: assetID)
    }
}

/// On-disk waveform cache.
///
/// JSON rather than a packed binary: a few thousand floats cost a handful of
/// kilobytes, and a cache that can be read by eye is a cache that can be
/// debugged. A corrupt file is discarded and re-extracted, never fatal.
enum WaveformCache {
    private static let logger = Logger(subsystem: "com.creativo.studio", category: "waveform")

    static var rootURL: URL {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? URL.temporaryDirectory
        return base.appending(path: "Creativo/Waveforms", directoryHint: .isDirectory)
    }

    static func url(assetID: UUID) -> URL {
        rootURL.appending(path: "\(assetID.uuidString).json", directoryHint: .notDirectory)
    }

    static func load(assetID: UUID) -> WaveformSamples? {
        let location = url(assetID: assetID)
        guard let data = try? Data(contentsOf: location) else { return nil }
        do {
            let samples = try JSONDecoder().decode(WaveformSamples.self, from: data)
            return samples.isEmpty ? nil : samples
        } catch {
            logger.error("Cache de waveform illisible, il sera régénéré.")
            try? FileManager.default.removeItem(at: location)
            return nil
        }
    }

    static func save(_ samples: WaveformSamples, assetID: UUID) {
        guard !samples.isEmpty else { return }
        do {
            try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(samples)
            try data.write(to: url(assetID: assetID), options: .atomic)
        } catch {
            // A cache that cannot be written only costs time, never data.
            logger.error("Écriture du cache impossible: \(String(describing: error))")
        }
    }

    static func remove(assetID: UUID) {
        try? FileManager.default.removeItem(at: url(assetID: assetID))
    }
}
