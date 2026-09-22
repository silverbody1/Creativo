import Foundation
import SwiftData

/// Creation, ordering and deletion of shots.
enum ShotService {
    @discardableResult
    static func create(
        in scene: StoryScene,
        title: String = "",
        shotSize: ShotSize = .medium,
        cameraMovement: CameraMovement = .fixed,
        in context: ModelContext
    ) -> Shot {
        let nextIndex = (scene.shots.map(\.orderIndex).max() ?? -1) + 1
        let shot = Shot(
            shotNumber: "\(scene.displayNumber)\(letter(for: nextIndex))",
            title: title,
            shotSize: shotSize,
            cameraMovement: cameraMovement,
            orderIndex: nextIndex
        )
        shot.scene = scene
        context.insert(shot)
        scene.touch()
        PersistenceActions.save(context)
        return shot
    }

    static func delete(_ shot: Shot, in context: ModelContext) {
        let scene = shot.scene
        context.delete(shot)
        if let scene {
            reindex(scene)
            scene.touch()
        }
        PersistenceActions.save(context)
    }

    static func setStatus(_ status: ShotStatus, on shot: Shot, in context: ModelContext) {
        guard shot.status != status else { return }
        shot.status = status
        shot.touch()
        PersistenceActions.save(context)
    }

    /// Cycles planned → ready → shot → planned, for one-tap progress on iPad.
    static func advanceStatus(of shot: Shot, in context: ModelContext) {
        let next: ShotStatus
        switch shot.status {
        case .planned: next = .ready
        case .ready: next = .shot
        case .shot: next = .planned
        case .cancelled: next = .planned
        }
        setStatus(next, on: shot, in: context)
    }

    static func move(
        fromOffsets offsets: IndexSet,
        toOffset destination: Int,
        in scene: StoryScene,
        context: ModelContext
    ) {
        var ordered = scene.sortedShots
        ordered.move(fromOffsets: offsets, toOffset: destination)
        apply(order: ordered, in: scene)
        PersistenceActions.save(context)
    }

    static func shift(_ shot: Shot, by delta: Int, in context: ModelContext) {
        guard let scene = shot.scene else { return }
        var ordered = scene.sortedShots
        guard let currentIndex = ordered.firstIndex(where: { $0.id == shot.id }) else { return }
        let newIndex = currentIndex + delta
        guard ordered.indices.contains(newIndex) else { return }
        ordered.swapAt(currentIndex, newIndex)
        apply(order: ordered, in: scene)
        PersistenceActions.save(context)
    }

    static func reindex(_ scene: StoryScene) {
        apply(order: scene.sortedShots, in: scene)
    }

    static func commitEdits(to shot: Shot, in context: ModelContext) {
        shot.touch()
        PersistenceActions.save(context)
    }

    /// `1A`, `1B`, … `1Z`, `1AA`. Matches how shot lists are numbered on set.
    static func letter(for index: Int) -> String {
        guard index >= 0 else { return "A" }
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        var value = index
        var result = ""
        repeat {
            result = String(alphabet[value % alphabet.count]) + result
            value = value / alphabet.count - 1
        } while value >= 0
        return result
    }

    private static func apply(order: [Shot], in scene: StoryScene) {
        for (index, shot) in order.enumerated() where shot.orderIndex != index {
            shot.orderIndex = index
        }
        scene.touch()
    }
}
