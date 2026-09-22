import Foundation
import SwiftData

/// Creation, ordering and deletion of scenes.
enum SceneService {
    @discardableResult
    static func create(
        in project: Project,
        title: String = "",
        environment: SceneEnvironment = .interior,
        timeOfDay: TimeOfDay = .day,
        in context: ModelContext
    ) -> StoryScene {
        let nextIndex = (project.scenes.map(\.orderIndex).max() ?? -1) + 1
        let scene = StoryScene(
            sceneNumber: "\(nextIndex + 1)",
            title: title,
            environment: environment,
            timeOfDay: timeOfDay,
            orderIndex: nextIndex
        )
        scene.project = project
        context.insert(scene)
        project.touch()
        PersistenceActions.save(context)
        return scene
    }

    static func delete(_ scene: StoryScene, in context: ModelContext) {
        let project = scene.project
        context.delete(scene)
        if let project {
            reindex(project)
            project.touch()
        }
        PersistenceActions.save(context)
    }

    /// Applies a drag-and-drop reorder coming from a `List`.
    static func move(
        fromOffsets offsets: IndexSet,
        toOffset destination: Int,
        in project: Project,
        context: ModelContext
    ) {
        var ordered = project.sortedScenes
        ordered.move(fromOffsets: offsets, toOffset: destination)
        apply(order: ordered, in: project)
        PersistenceActions.save(context)
    }

    /// Moves a single scene by one position, for the keyboard and context menu.
    static func shift(_ scene: StoryScene, by delta: Int, in context: ModelContext) {
        guard let project = scene.project else { return }
        var ordered = project.sortedScenes
        guard let currentIndex = ordered.firstIndex(where: { $0.id == scene.id }) else { return }
        let newIndex = currentIndex + delta
        guard ordered.indices.contains(newIndex) else { return }
        ordered.swapAt(currentIndex, newIndex)
        apply(order: ordered, in: project)
        PersistenceActions.save(context)
    }

    /// Rewrites `orderIndex` so it matches the current sort order exactly.
    static func reindex(_ project: Project) {
        apply(order: project.sortedScenes, in: project)
    }

    /// Renumbers every scene sequentially, discarding manual numbers such as "12A".
    static func renumberSequentially(_ project: Project, in context: ModelContext) {
        for (index, scene) in project.sortedScenes.enumerated() {
            scene.sceneNumber = "\(index + 1)"
            scene.orderIndex = index
        }
        project.touch()
        PersistenceActions.save(context)
    }

    static func commitEdits(to scene: StoryScene, in context: ModelContext) {
        scene.touch()
        PersistenceActions.save(context)
    }

    static func filter(_ scenes: [StoryScene], query: String) -> [StoryScene] {
        guard !query.isBlank else { return scenes }
        return scenes.filter { scene in
            scene.title.matches(query)
                || scene.synopsis.matches(query)
                || scene.content.matches(query)
                || scene.sceneNumber.matches(query)
                || (scene.location?.name.matches(query) ?? false)
        }
    }

    private static func apply(order: [StoryScene], in project: Project) {
        for (index, scene) in order.enumerated() where scene.orderIndex != index {
            scene.orderIndex = index
        }
        project.touch()
    }
}
