import Foundation
import SwiftData

/// A visual or sound reference attached to a project.
///
/// Only a path or a URL is persisted, never the bytes: large binaries in a
/// SwiftData store slow down every fetch and break future CloudKit sync. Files
/// live in the app's media folder, see `MediaStore`.
@Model
final class ReferenceAsset {
    var id: UUID = UUID()
    var title: String = ""
    var type: ReferenceType = ReferenceType.image
    /// Relative path inside the app's media folder, for imported files.
    var localPath: String?
    /// Absolute URL string, for web references.
    var remoteURLString: String?
    var notes: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var project: Project?

    init(
        title: String = "",
        type: ReferenceType = .image,
        localPath: String? = nil,
        remoteURLString: String? = nil,
        notes: String = "",
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.title = title
        self.type = type
        self.localPath = localPath
        self.remoteURLString = remoteURLString
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
}

extension ReferenceAsset {
    var displayTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Référence sans titre"
            : title
    }

    var remoteURL: URL? {
        guard let remoteURLString, !remoteURLString.isEmpty else { return nil }
        return URL(string: remoteURLString)
    }

    func touch(_ date: Date = .now) {
        updatedAt = date
        project?.touch(date)
    }
}
