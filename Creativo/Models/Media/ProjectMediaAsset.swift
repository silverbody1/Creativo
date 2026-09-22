import Foundation
import SwiftData

/// A media file belonging to a project.
///
/// The bytes never enter the store: importing copies the file into the app's
/// media folder and only its relative path is persisted. That is what keeps a
/// project exportable with its media, and what stops a track disappearing the
/// day the user empties their Downloads folder.
@Model
final class ProjectMediaAsset {
    var id: UUID = UUID()
    var type: MediaAssetType = MediaAssetType.audio
    /// Name shown in the interface; defaults to the original file name.
    var displayName: String = ""
    var originalFilename: String = ""
    /// Path inside the app's media folder, never an absolute one.
    var localRelativePath: String = ""
    /// Length in seconds, read once at import.
    var duration: TimeInterval = 0
    /// Sample rate in hertz, when the format exposes one.
    var sampleRate: Double?
    var fileSize: Int64 = 0
    var importedAt: Date = Date()
    var notes: String = ""

    var project: Project?

    init(
        type: MediaAssetType = .audio,
        displayName: String = "",
        originalFilename: String = "",
        localRelativePath: String = "",
        duration: TimeInterval = 0,
        sampleRate: Double? = nil,
        fileSize: Int64 = 0,
        importedAt: Date = .now,
        notes: String = ""
    ) {
        self.id = UUID()
        self.type = type
        self.displayName = displayName
        self.originalFilename = originalFilename
        self.localRelativePath = localRelativePath
        self.duration = duration
        self.sampleRate = sampleRate
        self.fileSize = fileSize
        self.importedAt = importedAt
        self.notes = notes
    }
}

extension ProjectMediaAsset {
    var title: String {
        if !displayName.isBlank { return displayName.trimmed }
        if !originalFilename.isBlank { return originalFilename }
        return "Média sans nom"
    }

    /// Absolute location of the file, resolved through the media store.
    var fileURL: URL {
        MediaStore.shared.url(forRelativePath: localRelativePath)
    }

    /// `false` when the file has been moved or deleted behind the app's back.
    var isAvailable: Bool {
        !localRelativePath.isBlank
            && FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false))
    }

    /// `4,2 Mo`
    var fileSizeText: String {
        guard fileSize > 0 else { return "—" }
        return fileSize.formatted(.byteCount(style: .file))
    }

    /// `44,1 kHz`
    var sampleRateText: String {
        guard let sampleRate, sampleRate > 0 else { return "—" }
        let kilohertz = (sampleRate / 1000).formatted(.number.precision(.fractionLength(0...1)))
        return "\(kilohertz) kHz"
    }
}

/// What a media asset holds. Only audio is used in this phase; the other cases
/// exist so the storyboard and moodboard phases have somewhere to land.
enum MediaAssetType: String, Codable, CaseIterable, Identifiable, Sendable {
    case audio
    case image
    case video
    case document

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .audio: return "Audio"
        case .image: return "Image"
        case .video: return "Vidéo"
        case .document: return "Document"
        }
    }

    var symbolName: String {
        switch self {
        case .audio: return "waveform"
        case .image: return "photo"
        case .video: return "film"
        case .document: return "doc"
        }
    }
}
