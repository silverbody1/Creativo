import Foundation
import AVFoundation

/// Standard tags carried by an audio file.
///
/// Nothing is guessed here: this reads the common metadata the format already
/// declares. Recognising a verse from a chorus is a later phase and will not
/// pretend to happen in an importer.
enum AudioMetadata {
    struct Info: Equatable, Sendable {
        var title: String?
        var artist: String?
        var album: String?

        var isEmpty: Bool { title == nil && artist == nil && album == nil }

        /// `NAYRA — Partenaire`, or whichever half exists.
        var summary: String? {
            let parts = [artist, title].compactMap { $0 }
            return parts.isEmpty ? nil : parts.joined(separator: " — ")
        }
    }

    /// Reads title, artist and album, asynchronously and off the main actor.
    /// A file with no tags simply returns an empty `Info`.
    static func read(from url: URL) async -> Info {
        let asset = AVURLAsset(url: url)
        guard let items = try? await asset.load(.commonMetadata), !items.isEmpty else {
            return Info()
        }

        var info = Info()
        info.title = await string(from: items, identifier: .commonIdentifierTitle)
        info.artist = await string(from: items, identifier: .commonIdentifierArtist)
        info.album = await string(from: items, identifier: .commonIdentifierAlbumName)
        return info
    }

    private static func string(
        from items: [AVMetadataItem],
        identifier: AVMetadataIdentifier
    ) async -> String? {
        guard let item = AVMetadataItem.metadataItems(from: items, filteredByIdentifier: identifier).first else {
            return nil
        }
        let value = (try? await item.load(.stringValue)) ?? nil
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
