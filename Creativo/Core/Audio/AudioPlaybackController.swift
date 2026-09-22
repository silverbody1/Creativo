import Foundation
import AVFoundation
import Observation
import OSLog

/// Time arithmetic of the transport, kept separate so it can be tested without
/// a file, a device or a run loop.
enum PlaybackMath {
    /// One PAL frame: fine enough to land on a beat, coarse enough to feel
    /// deliberate under an arrow key.
    static let fineStep: TimeInterval = 1.0 / 25.0
    static let coarseStep: TimeInterval = 5

    static func clamp(_ time: TimeInterval, duration: TimeInterval) -> TimeInterval {
        guard duration > 0 else { return max(time, 0) }
        return min(max(time, 0), duration)
    }

    static func skipped(from time: TimeInterval, by delta: TimeInterval, duration: TimeInterval) -> TimeInterval {
        clamp(time + delta, duration: duration)
    }

    /// 0 to 1, for progress bars. A zero-length track reports no progress
    /// rather than dividing by zero.
    static func progress(_ time: TimeInterval, duration: TimeInterval) -> Double {
        guard duration > 0 else { return 0 }
        return min(max(time / duration, 0), 1)
    }
}

/// Plays the project's track and publishes the playhead position.
///
/// The current time lives here and **never** in SwiftData: it changes thirty
/// times a second and means nothing once the window closes. Only views that
/// actually draw the playhead read `currentTime`, so a tick does not rebuild
/// the timeline.
@MainActor
@Observable
final class AudioPlaybackController {
    private(set) var isPlaying = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var loadedAssetID: UUID?
    /// Set when the file could not be opened, so the interface can offer to
    /// relink it instead of pretending everything is fine.
    private(set) var failureMessage: String?

    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var tickerTask: Task<Void, Never>?
    @ObservationIgnored private let logger = Logger(subsystem: "com.creativo.studio", category: "playback")

    var hasAudio: Bool { player != nil }
    var progress: Double { PlaybackMath.progress(currentTime, duration: duration) }

    // MARK: Loading

    /// Opens a track. Reloading the same asset is a no-op, so switching
    /// sections does not restart playback.
    func load(assetID: UUID, url: URL, fallbackDuration: TimeInterval) {
        if loadedAssetID == assetID, player != nil { return }
        unload()
        configureSessionIfNeeded()

        do {
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.prepareToPlay()
            player = newPlayer
            duration = newPlayer.duration > 0 ? newPlayer.duration : fallbackDuration
            loadedAssetID = assetID
            currentTime = 0
            failureMessage = nil
        } catch {
            player = nil
            loadedAssetID = nil
            duration = fallbackDuration
            failureMessage = "Lecture impossible : \(error.localizedDescription)"
            logger.error("Ouverture audio impossible: \(String(describing: error))")
        }
    }

    func unload() {
        stopTicker()
        player?.stop()
        player = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        loadedAssetID = nil
        failureMessage = nil
    }

    /// Lets the timeline be scrubbed before any track has been imported, using
    /// the length the sections already describe.
    func adoptDurationIfNeeded(_ value: TimeInterval) {
        guard player == nil, value > 0, duration != value else { return }
        duration = value
        currentTime = PlaybackMath.clamp(currentTime, duration: value)
    }

    // MARK: Transport

    func play() {
        guard let player else { return }
        if currentTime >= duration - 0.01 { seek(to: 0) }
        player.currentTime = currentTime
        guard player.play() else {
            failureMessage = "La lecture n'a pas pu démarrer."
            return
        }
        isPlaying = true
        startTicker()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        stopTicker()
        if let player { currentTime = player.currentTime }
    }

    func toggle() {
        isPlaying ? pause() : play()
    }

    func seek(to time: TimeInterval) {
        let target = PlaybackMath.clamp(time, duration: duration)
        currentTime = target
        player?.currentTime = target
    }

    func skip(by delta: TimeInterval) {
        seek(to: PlaybackMath.skipped(from: currentTime, by: delta, duration: duration))
    }

    func restart() {
        seek(to: 0)
    }

    // MARK: Ticking

    private func startTicker() {
        stopTicker()
        tickerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(33))
                guard let self else { return }
                self.tick()
            }
        }
    }

    private func stopTicker() {
        tickerTask?.cancel()
        tickerTask = nil
    }

    private func tick() {
        guard let player else {
            stopTicker()
            return
        }
        if player.isPlaying {
            currentTime = player.currentTime
        } else if isPlaying {
            // Reached the end: AVAudioPlayer rewinds itself, the playhead
            // should stay where the music stopped.
            isPlaying = false
            currentTime = duration
            stopTicker()
        }
    }

    private func configureSessionIfNeeded() {
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            logger.error("Session audio indisponible: \(String(describing: error))")
        }
        #endif
    }
}
