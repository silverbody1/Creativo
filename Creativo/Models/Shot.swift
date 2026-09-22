import Foundation
import SwiftData

/// A single shot inside a scene.
@Model
final class Shot {
    var id: UUID = UUID()
    var shotNumber: String = ""
    var title: String = ""
    /// Not named `description`: that identifier is reserved in practice by
    /// `CustomStringConvertible` and makes debugging output confusing.
    var details: String = ""
    var shotSize: ShotSize = ShotSize.medium
    var cameraMovement: CameraMovement = CameraMovement.fixed
    var lens: String = ""
    /// Frames per second. Fractional values such as 23.976 are supported.
    var frameRate: Double = 25
    var status: ShotStatus = ShotStatus.planned
    var orderIndex: Int = 0
    var notes: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var scene: StoryScene?

    init(
        shotNumber: String = "",
        title: String = "",
        details: String = "",
        shotSize: ShotSize = .medium,
        cameraMovement: CameraMovement = .fixed,
        lens: String = "",
        frameRate: Double = 25,
        status: ShotStatus = .planned,
        orderIndex: Int = 0,
        notes: String = "",
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.shotNumber = shotNumber
        self.title = title
        self.details = details
        self.shotSize = shotSize
        self.cameraMovement = cameraMovement
        self.lens = lens
        self.frameRate = frameRate
        self.status = status
        self.orderIndex = orderIndex
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
}

extension Shot {
    /// Frame rates offered by the shot editor, from cinema to high speed.
    static let commonFrameRates: [Double] = [23.976, 24, 25, 29.97, 30, 48, 50, 59.94, 60, 100, 120, 240]

    var displayTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Plan sans titre"
            : title
    }

    var displayNumber: String {
        let trimmed = shotNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "\(orderIndex + 1)" : trimmed
    }

    /// `Plan moyen · Travelling latéral · 35 mm` for the row subtitle.
    var technicalSummary: String {
        var parts = [shotSize.displayName, cameraMovement.displayName]
        let trimmedLens = lens.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedLens.isEmpty { parts.append(trimmedLens) }
        return parts.joined(separator: " · ")
    }

    func touch(_ date: Date = .now) {
        updatedAt = date
        scene?.touch(date)
    }
}
