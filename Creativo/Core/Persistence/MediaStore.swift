import Foundation
import OSLog

/// Owns the folder where imported media live.
///
/// SwiftData stores *paths*, never bytes. Keeping binaries out of the store is
/// what makes fetches fast today and CloudKit sync realistic tomorrow, and it
/// lets the storyboard and moodboard phases drop in large images without
/// reshaping the schema.
struct MediaStore: Sendable {
    static let shared = MediaStore()

    private let logger = Logger(subsystem: "com.creativo.studio", category: "media")

    /// `~/Library/Application Support/Creativo/Media` on both platforms.
    var rootURL: URL {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? URL.temporaryDirectory
        return base.appending(path: "Creativo/Media", directoryHint: .isDirectory)
    }

    /// Resolves a stored relative path into an absolute URL.
    func url(forRelativePath path: String) -> URL {
        rootURL.appending(path: path, directoryHint: .notDirectory)
    }

    /// Copies an external file into the media folder and returns the relative
    /// path to persist. Returns `nil` when the copy fails; callers keep working
    /// without a local file rather than losing the record.
    @discardableResult
    func importFile(at sourceURL: URL, preferredName: String? = nil) -> String? {
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
            let ext = sourceURL.pathExtension
            let base = preferredName ?? UUID().uuidString
            let fileName = ext.isEmpty ? base : "\(base).\(ext)"
            let destination = rootURL.appending(path: fileName, directoryHint: .notDirectory)
            if fileManager.fileExists(atPath: destination.path(percentEncoded: false)) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: sourceURL, to: destination)
            return fileName
        } catch {
            logger.error("Import du média impossible: \(String(describing: error))")
            return nil
        }
    }

    /// Removes a file previously imported. Missing files are not an error.
    func removeFile(relativePath: String) {
        let target = url(forRelativePath: relativePath)
        try? FileManager.default.removeItem(at: target)
    }
}
