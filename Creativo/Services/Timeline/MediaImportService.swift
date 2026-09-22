import Foundation
import SwiftData
import OSLog

/// Brings an external audio file into a project.
///
/// The file is **copied** into the app's media folder rather than referenced
/// where the user happened to leave it. A bookmark to a file in Downloads is a
/// broken project waiting to happen, and a copy is what will let a project be
/// exported with its media later.
enum MediaImportService {
    private static let logger = Logger(subsystem: "com.creativo.studio", category: "media")

    static let supportedAudioExtensions: Set<String> = [
        "wav", "aif", "aiff", "aifc", "mp3", "m4a", "aac", "caf"
    ]

    enum Failure: LocalizedError, Equatable {
        case unsupportedFormat(String)
        case notReadable
        case copyFailed
        case notAudio

        var errorDescription: String? {
            switch self {
            case .unsupportedFormat(let ext):
                return "Le format « .\(ext) » n'est pas pris en charge. Utilisez WAV, AIFF, MP3 ou M4A."
            case .notReadable:
                return "Le fichier n'a pas pu être lu."
            case .copyFailed:
                return "Le fichier n'a pas pu être copié dans le projet."
            case .notAudio:
                return "Ce fichier ne contient pas de piste audio exploitable."
            }
        }
    }

    static func isSupportedAudio(_ url: URL) -> Bool {
        supportedAudioExtensions.contains(url.pathExtension.lowercased())
    }

    /// Copies the track in, reads its length, and makes it the project's
    /// primary audio. Never touches the existing sections.
    @discardableResult
    static func importAudio(
        from sourceURL: URL,
        into project: Project,
        makePrimary: Bool = true,
        context: ModelContext
    ) throws -> ProjectMediaAsset {
        let ext = sourceURL.pathExtension.lowercased()
        guard supportedAudioExtensions.contains(ext) else {
            throw Failure.unsupportedFormat(ext.isEmpty ? "inconnu" : ext)
        }

        // A file chosen through the open panel is sandboxed on macOS: access
        // has to be claimed before reading and released afterwards.
        let scoped = sourceURL.startAccessingSecurityScopedResource()
        defer { if scoped { sourceURL.stopAccessingSecurityScopedResource() } }

        guard FileManager.default.isReadableFile(atPath: sourceURL.path(percentEncoded: false)) else {
            throw Failure.notReadable
        }

        let asset = ProjectMediaAsset(
            type: .audio,
            displayName: sourceURL.deletingPathExtension().lastPathComponent,
            originalFilename: sourceURL.lastPathComponent
        )

        guard let relativePath = MediaStore.shared.importFile(
            at: sourceURL,
            preferredName: "audio-\(asset.id.uuidString)"
        ) else {
            throw Failure.copyFailed
        }
        asset.localRelativePath = relativePath

        let copiedURL = MediaStore.shared.url(forRelativePath: relativePath)
        guard let probe = WaveformExtractor.probe(url: copiedURL) else {
            MediaStore.shared.removeFile(relativePath: relativePath)
            throw Failure.notAudio
        }
        asset.duration = probe.duration
        asset.sampleRate = probe.sampleRate
        asset.fileSize = fileSize(of: copiedURL)

        asset.project = project
        context.insert(asset)
        if makePrimary {
            project.primaryAudioAssetID = asset.id
        }
        project.touch()
        PersistenceActions.save(context)
        logger.notice("Audio importé: \(asset.originalFilename, privacy: .public)")
        return asset
    }

    /// Swaps the track. Sections, markers and shots are kept; only the ones
    /// that now fall outside the new length are pulled back inside it.
    @discardableResult
    static func replaceAudio(
        of project: Project,
        with sourceURL: URL,
        context: ModelContext
    ) throws -> ProjectMediaAsset {
        let previous = project.primaryAudioAsset
        let asset = try importAudio(from: sourceURL, into: project, context: context)
        if let previous, previous.id != asset.id {
            remove(previous, from: project, context: context)
        }
        project.primaryAudioAssetID = asset.id
        MusicTimelineService.clampToDuration(project, context: context)
        return asset
    }

    /// Detaches and deletes a media asset, its file and its cached waveform.
    static func remove(_ asset: ProjectMediaAsset, from project: Project, context: ModelContext) {
        let assetID = asset.id
        if !asset.localRelativePath.isBlank {
            MediaStore.shared.removeFile(relativePath: asset.localRelativePath)
        }
        Task { await WaveformStore.shared.invalidate(assetID: assetID) }

        project.mediaAssets.removeAll { $0.id == assetID }
        context.delete(asset)
        if project.primaryAudioAssetID == assetID {
            project.primaryAudioAssetID = project.audioAssets.first?.id
        }
        project.touch()
        PersistenceActions.save(context)
    }

    /// Renames an imported track from the tags the file already carries.
    ///
    /// Run after the import rather than during it, so a file with slow or
    /// missing metadata never delays the moment the waveform appears. Nothing
    /// is invented: a file without tags keeps the name it was given.
    @MainActor
    static func refreshMetadata(for asset: ProjectMediaAsset, context: ModelContext) async {
        guard asset.isAvailable else { return }
        let info = await AudioMetadata.read(from: asset.fileURL)
        guard !info.isEmpty else { return }

        if let title = info.title {
            asset.displayName = title
        }
        if let artist = info.artist, asset.notes.isBlank {
            asset.notes = info.album.map { "\(artist) · \($0)" } ?? artist
        }
        asset.project?.touch()
        PersistenceActions.save(context)
    }

    private static func fileSize(of url: URL) -> Int64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path(percentEncoded: false))
        return (attributes?[.size] as? NSNumber)?.int64Value ?? 0
    }
}
