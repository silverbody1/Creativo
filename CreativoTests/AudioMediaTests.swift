import XCTest
import AVFoundation
import SwiftData
@testable import Creativo

/// End-to-end media tests against a real audio file generated on the fly.
///
/// Writing a one-second tone and reading it back is the only way to know that
/// import, probing and extraction actually work; mocking the file system here
/// would test the mock.
final class AudioMediaTests: CreativoTestCase {
    private var temporaryFiles: [URL] = []

    override func tearDownWithError() throws {
        for url in temporaryFiles {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryFiles = []
        try super.tearDownWithError()
    }

    private func makeAudioFile(duration: TimeInterval, frequency: Double = 440) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "creativo-test-\(UUID().uuidString).caf", directoryHint: .notDirectory)

        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1) else {
            throw XCTSkip("Format audio indisponible sur cette machine.")
        }
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        let frames = AVAudioFrameCount(44_100 * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else {
            throw XCTSkip("Tampon audio indisponible sur cette machine.")
        }
        buffer.frameLength = frames
        if let channel = buffer.floatChannelData?[0] {
            for frame in 0..<Int(frames) {
                channel[frame] = Float(sin(2 * Double.pi * frequency * Double(frame) / 44_100) * 0.8)
            }
        }
        try file.write(from: buffer)
        temporaryFiles.append(url)
        return url
    }

    // MARK: Reading a file

    func testProbeReadsDurationAndSampleRate() throws {
        let url = try makeAudioFile(duration: 1)
        let probe = try XCTUnwrap(WaveformExtractor.probe(url: url))
        XCTAssertEqual(probe.duration, 1, accuracy: 0.05)
        XCTAssertEqual(probe.sampleRate, 44_100, accuracy: 1)
    }

    func testExtractionProducesANormalisedEnvelope() throws {
        let url = try makeAudioFile(duration: 1)
        let samples = try WaveformExtractor.extract(from: url, bucketCount: 200)

        XCTAssertFalse(samples.isEmpty)
        XCTAssertEqual(samples.duration, 1, accuracy: 0.05)
        XCTAssertLessThanOrEqual(samples.peaks.count, 200)
        XCTAssertTrue(samples.peaks.allSatisfy { $0 >= 0 && $0 <= 1 })
        // A 0.8 amplitude tone must register well above silence.
        XCTAssertGreaterThan(samples.peaks.max() ?? 0, 0.5)
    }

    func testExtractingSomethingThatIsNotAudioFails() throws {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "creativo-test-\(UUID().uuidString).caf", directoryHint: .notDirectory)
        try Data("ceci n'est pas un son".utf8).write(to: url)
        temporaryFiles.append(url)

        XCTAssertThrowsError(try WaveformExtractor.extract(from: url))
        XCTAssertNil(WaveformExtractor.probe(url: url))
    }

    // MARK: Metadata

    func testMetadataSummaryJoinsWhatIsThere() {
        XCTAssertEqual(
            AudioMetadata.Info(title: "Partenaire", artist: "NAYRA").summary,
            "NAYRA — Partenaire"
        )
        XCTAssertEqual(AudioMetadata.Info(title: "Partenaire").summary, "Partenaire")
        XCTAssertEqual(AudioMetadata.Info(artist: "NAYRA").summary, "NAYRA")
        XCTAssertNil(AudioMetadata.Info().summary)
        XCTAssertTrue(AudioMetadata.Info().isEmpty)
        XCTAssertFalse(AudioMetadata.Info(album: "Premier").isEmpty)
    }

    func testAFileWithoutTagsReadsAsEmptyRatherThanFailing() async throws {
        let url = try makeAudioFile(duration: 0.5)
        let info = await AudioMetadata.read(from: url)
        XCTAssertTrue(info.isEmpty)
    }

    func testReadingMetadataFromSomethingUnreadableIsHarmless() async throws {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "creativo-test-\(UUID().uuidString).m4a", directoryHint: .notDirectory)
        try Data("pas un son".utf8).write(to: url)
        temporaryFiles.append(url)

        let info = await AudioMetadata.read(from: url)
        XCTAssertTrue(info.isEmpty)
    }

    @MainActor
    func testRefreshingMetadataKeepsTheNameWhenThereAreNoTags() async throws {
        let project = ProjectService.create(name: "PARTENAIRE", type: .musicVideo, context: context)
        let url = try makeAudioFile(duration: 0.5)
        let asset = try MediaImportService.importAudio(from: url, into: project, context: context)
        let originalName = asset.displayName

        await MediaImportService.refreshMetadata(for: asset, context: context)

        XCTAssertEqual(asset.displayName, originalName)
        MediaImportService.remove(asset, from: project, context: context)
    }

    // MARK: Importing

    func testImportingCopiesTheFileIntoTheProject() throws {
        let project = ProjectService.create(name: "PARTENAIRE", type: .musicVideo, context: context)
        let url = try makeAudioFile(duration: 1)

        let asset = try MediaImportService.importAudio(from: url, into: project, context: context)

        XCTAssertEqual(project.mediaAssets.count, 1)
        XCTAssertEqual(project.primaryAudioAsset?.id, asset.id)
        XCTAssertEqual(asset.type, .audio)
        XCTAssertEqual(asset.duration, 1, accuracy: 0.05)
        XCTAssertGreaterThan(asset.fileSize, 0)
        XCTAssertTrue(asset.isAvailable)
        // The copy is the app's, not a pointer into the user's Downloads.
        XCTAssertNotEqual(asset.fileURL, url)
        XCTAssertEqual(project.timelineDuration, asset.duration, accuracy: 0.05)

        MediaImportService.remove(asset, from: project, context: context)
    }

    func testAnUnsupportedFormatIsRefusedWithoutSideEffects() throws {
        let project = ProjectService.create(name: "PARTENAIRE", type: .musicVideo, context: context)
        let url = FileManager.default.temporaryDirectory
            .appending(path: "creativo-test-\(UUID().uuidString).xyz", directoryHint: .notDirectory)
        try Data("nope".utf8).write(to: url)
        temporaryFiles.append(url)

        XCTAssertThrowsError(try MediaImportService.importAudio(from: url, into: project, context: context)) { error in
            XCTAssertEqual(error as? MediaImportService.Failure, .unsupportedFormat("xyz"))
        }
        XCTAssertTrue(project.mediaAssets.isEmpty)
        XCTAssertNil(project.primaryAudioAssetID)
    }

    func testReplacingTheTrackKeepsEverySceneAndMarker() throws {
        let project = ProjectService.create(name: "PARTENAIRE", type: .musicVideo, context: context)
        let long = try makeAudioFile(duration: 2)
        let first = try MediaImportService.importAudio(from: long, into: project, context: context)

        let intro = MusicTimelineService.createSection(at: 0, kind: .intro, in: project, context: context)
        let verse = MusicTimelineService.createSection(at: 1.2, kind: .verse, in: project, context: context)
        let marker = MusicTimelineService.addMarker(at: 1.8, title: "drop", type: .beat, in: project, context: context)
        let shot = ShotService.create(in: intro, title: "Ouverture", context: context)
        XCTAssertEqual(project.musicSections.count, 2)

        let short = try makeAudioFile(duration: 1)
        let second = try MediaImportService.replaceAudio(of: project, with: short, context: context)

        // Nothing written is lost when the track changes.
        XCTAssertEqual(project.musicSections.count, 2)
        XCTAssertEqual(project.markers.count, 1)
        XCTAssertEqual(intro.shots.map(\.id), [shot.id])
        XCTAssertNotEqual(second.id, first.id)
        XCTAssertEqual(project.primaryAudioAssetID, second.id)
        XCTAssertEqual(project.mediaAssets.count, 1)

        // And everything that no longer fits has been pulled inside.
        XCTAssertLessThanOrEqual(try XCTUnwrap(verse.musicFacet?.endTime), project.timelineDuration + 0.001)
        XCTAssertLessThanOrEqual(marker.time, project.timelineDuration + 0.001)

        MediaImportService.remove(second, from: project, context: context)
    }

    func testRemovingTheTrackDeletesItsFileButKeepsTheWork() throws {
        let project = ProjectService.create(name: "PARTENAIRE", type: .musicVideo, context: context)
        let url = try makeAudioFile(duration: 1)
        let asset = try MediaImportService.importAudio(from: url, into: project, context: context)
        MusicTimelineService.createSection(at: 0, kind: .intro, in: project, context: context)
        let copiedPath = asset.fileURL

        MediaImportService.remove(asset, from: project, context: context)

        XCTAssertTrue(project.mediaAssets.isEmpty)
        XCTAssertNil(project.primaryAudioAssetID)
        XCTAssertFalse(FileManager.default.fileExists(atPath: copiedPath.path(percentEncoded: false)))
        XCTAssertEqual(project.musicSections.count, 1)
        XCTAssertEqual(try countOf(ProjectMediaAsset.self), 0)
    }

    func testAMissingFileIsReportedRatherThanCrashing() throws {
        let project = ProjectService.create(name: "PARTENAIRE", type: .musicVideo, context: context)
        let url = try makeAudioFile(duration: 1)
        let asset = try MediaImportService.importAudio(from: url, into: project, context: context)

        // Someone empties the media folder behind the app's back.
        MediaStore.shared.removeFile(relativePath: asset.localRelativePath)

        XCTAssertFalse(asset.isAvailable)
        XCTAssertEqual(project.primaryAudioAsset?.id, asset.id)
        XCTAssertEqual(asset.duration, 1, accuracy: 0.05)

        MediaImportService.remove(asset, from: project, context: context)
    }

    func testDeletingTheProjectDeletesItsMediaRecords() throws {
        let project = ProjectService.create(name: "PARTENAIRE", type: .musicVideo, context: context)
        let url = try makeAudioFile(duration: 1)
        let asset = try MediaImportService.importAudio(from: url, into: project, context: context)
        let copiedPath = asset.fileURL

        ProjectService.delete(project, context: context)

        XCTAssertEqual(try countOf(ProjectMediaAsset.self), 0)
        // The file itself is cleaned up by the media store on removal, not by
        // the cascade, so it is still there: tidy it up rather than leak it.
        try? FileManager.default.removeItem(at: copiedPath)
    }
}
