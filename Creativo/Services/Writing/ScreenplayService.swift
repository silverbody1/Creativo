import Foundation
import SwiftData

/// Creation, typing, ordering and deletion of screenplay elements.
///
/// Every mutation goes through here so that two invariants always hold: the
/// order indices stay contiguous, and `StoryScene.content` keeps a readable
/// plain-text copy of what the editor shows.
enum ScreenplayService {
    // MARK: Elements

    @discardableResult
    static func append(
        _ type: ScreenplayElementType = .action,
        text: String = "",
        to scene: StoryScene,
        context: ModelContext
    ) -> ScreenplayElement {
        let nextIndex = (scene.screenplayElements.map(\.orderIndex).max() ?? -1) + 1
        let element = ScreenplayElement(type: type, text: text, orderIndex: nextIndex)
        element.scene = scene
        context.insert(element)
        finish(scene, context: context)
        return element
    }

    /// Inserts a new element right after `element`, which is what pressing
    /// "new line" in the editor does.
    @discardableResult
    static func insert(
        _ type: ScreenplayElementType? = nil,
        after element: ScreenplayElement,
        context: ModelContext
    ) -> ScreenplayElement? {
        guard let scene = element.scene else { return nil }
        let resolvedType = type ?? element.type.naturalSuccessor
        let inserted = ScreenplayElement(type: resolvedType, orderIndex: element.orderIndex + 1)
        inserted.scene = scene
        context.insert(inserted)

        for other in scene.screenplayElements where other.id != inserted.id && other.orderIndex > element.orderIndex {
            other.orderIndex += 1
        }
        finish(scene, context: context)
        return inserted
    }

    static func setType(
        _ type: ScreenplayElementType,
        on element: ScreenplayElement,
        context: ModelContext
    ) {
        guard element.type != type else { return }
        element.type = type
        if let scene = element.scene {
            finish(scene, context: context)
        }
    }

    static func delete(_ element: ScreenplayElement, context: ModelContext) {
        let scene = element.scene
        // See `SceneService.delete`: detach first so the reindex and the
        // plain-text copy both reflect the removal straight away.
        scene?.screenplayElements.removeAll { $0.id == element.id }
        context.delete(element)
        if let scene {
            reindex(scene)
            finish(scene, context: context)
        }
    }

    static func move(
        fromOffsets offsets: IndexSet,
        toOffset destination: Int,
        in scene: StoryScene,
        context: ModelContext
    ) {
        var ordered = scene.sortedScreenplayElements
        ordered.move(fromOffsets: offsets, toOffset: destination)
        apply(order: ordered)
        finish(scene, context: context)
    }

    /// Moves one element by a single position, for the keyboard and the menu.
    static func shift(_ element: ScreenplayElement, by delta: Int, context: ModelContext) {
        guard let scene = element.scene else { return }
        var ordered = scene.sortedScreenplayElements
        guard let index = ordered.firstIndex(where: { $0.id == element.id }) else { return }
        let target = index + delta
        guard ordered.indices.contains(target) else { return }
        ordered.swapAt(index, target)
        apply(order: ordered)
        finish(scene, context: context)
    }

    /// Called when the user stops typing in an element.
    static func commitEdits(to element: ScreenplayElement, context: ModelContext) {
        element.touch()
        if let scene = element.scene {
            finish(scene, context: context)
        } else {
            PersistenceActions.save(context)
        }
    }

    /// Removes the trailing empty elements a writing session leaves behind.
    static func trimTrailingEmptyElements(in scene: StoryScene, context: ModelContext) {
        var ordered = scene.sortedScreenplayElements
        var removed = false
        while let last = ordered.last, last.isEmpty {
            ordered.removeLast()
            scene.screenplayElements.removeAll { $0.id == last.id }
            context.delete(last)
            removed = true
        }
        guard removed else { return }
        apply(order: ordered)
        finish(scene, context: context)
    }

    // MARK: Import of pre-existing text

    /// Fills a scene's elements from its plain-text `content` the first time it
    /// is opened in the editor.
    ///
    /// Returns `true` when something was imported. Scenes written before this
    /// phase therefore keep every word they had, and a scene that already has
    /// elements is never touched.
    @discardableResult
    static func importPlainTextIfNeeded(into scene: StoryScene, context: ModelContext) -> Bool {
        guard scene.screenplayElements.isEmpty, !scene.content.isBlank else { return false }

        let parsed = ScreenplayFormatter.parse(scene.content)
        guard !parsed.isEmpty else { return false }

        for (index, item) in parsed.enumerated() {
            let element = ScreenplayElement(type: item.type, text: item.text, orderIndex: index)
            element.scene = scene
            context.insert(element)
        }
        finish(scene, context: context)
        return true
    }

    /// Prepares every scene of a project for the screenplay editor.
    static func prepare(_ project: Project, context: ModelContext) {
        var changed = false
        for scene in project.sortedScenes {
            if importPlainTextIfNeeded(into: scene, context: context) { changed = true }
        }
        if changed { PersistenceActions.save(context) }
    }

    // MARK: Ordering and synchronisation

    static func reindex(_ scene: StoryScene) {
        apply(order: scene.sortedScreenplayElements)
    }

    private static func apply(order: [ScreenplayElement]) {
        for (index, element) in order.enumerated() where element.orderIndex != index {
            element.orderIndex = index
        }
    }

    /// Single exit point of every mutation: keep the plain-text copy in sync,
    /// stamp the scene as modified, save.
    private static func finish(_ scene: StoryScene, context: ModelContext) {
        syncPlainText(for: scene)
        scene.touch()
        PersistenceActions.save(context)
    }

    /// Mirrors the typed elements into `StoryScene.content`.
    ///
    /// Always rewrites, including when the last line has just been deleted:
    /// keeping the previous text would leave the Scenes screen showing
    /// something the editor no longer contains. Scenes never opened in the
    /// editor are unaffected, because nothing here runs for them.
    static func syncPlainText(for scene: StoryScene) {
        scene.content = ScreenplayFormatter.plainText(for: scene)
    }
}
