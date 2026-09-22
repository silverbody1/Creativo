import Foundation
import SwiftData

/// Figures shown at the top of the YouTube script editor.
struct ScriptMetrics: Equatable, Sendable {
    var totalWords: Int
    var spokenWords: Int
    var sectionCount: Int
    var blockCount: Int
    /// Estimated spoken duration, in seconds.
    var estimatedDuration: TimeInterval

    static let empty = ScriptMetrics(
        totalWords: 0,
        spokenWords: 0,
        sectionCount: 0,
        blockCount: 0,
        estimatedDuration: 0
    )
}

/// Word counting and duration estimation. Pure, therefore directly testable.
enum ScriptMetricsCalculator {
    /// Speaking rates that cover how people actually present on camera.
    static let speakingRates = [110, 130, 150, 170, 190]
    static let defaultWordsPerMinute = 150

    static func wordCount(in text: String) -> Int {
        text.split { $0.isWhitespace || $0.isNewline }.count
    }

    static func metrics(for blocks: [YouTubeBlock], wordsPerMinute: Int) -> ScriptMetrics {
        var total = 0
        var spoken = 0
        var sections = 0
        for block in blocks {
            total += wordCount(in: block.text)
            spoken += block.spokenWordCount
            if block.kind.isHeader { sections += 1 }
        }
        let rate = max(wordsPerMinute, 1)
        return ScriptMetrics(
            totalWords: total,
            spokenWords: spoken,
            sectionCount: sections,
            blockCount: blocks.count,
            estimatedDuration: Double(spoken) / Double(rate) * 60
        )
    }
}

/// Creation, ordering, folding and promotion of YouTube script blocks.
enum YouTubeScriptService {
    // MARK: Blocks

    @discardableResult
    static func append(
        _ kind: YouTubeBlockKind,
        title: String = "",
        text: String = "",
        to project: Project,
        context: ModelContext
    ) -> YouTubeBlock {
        let nextIndex = (project.youtubeBlocks.map(\.orderIndex).max() ?? -1) + 1
        let block = YouTubeBlock(kind: kind, title: title, text: text, orderIndex: nextIndex)
        block.project = project
        context.insert(block)
        finish(project, context: context)
        return block
    }

    @discardableResult
    static func insert(
        _ kind: YouTubeBlockKind,
        after block: YouTubeBlock,
        context: ModelContext
    ) -> YouTubeBlock? {
        guard let project = block.project else { return nil }
        let inserted = YouTubeBlock(kind: kind, orderIndex: block.orderIndex + 1)
        inserted.project = project
        context.insert(inserted)

        for other in project.youtubeBlocks where other.id != inserted.id && other.orderIndex > block.orderIndex {
            other.orderIndex += 1
        }
        finish(project, context: context)
        return inserted
    }

    static func setKind(_ kind: YouTubeBlockKind, on block: YouTubeBlock, context: ModelContext) {
        guard block.kind != kind else { return }
        block.kind = kind
        if !kind.isHeader { block.isCollapsed = false }
        block.touch()
        PersistenceActions.save(context)
    }

    static func delete(_ block: YouTubeBlock, context: ModelContext) {
        let project = block.project
        context.delete(block)
        if let project {
            reindex(project)
            finish(project, context: context)
        }
    }

    static func move(
        fromOffsets offsets: IndexSet,
        toOffset destination: Int,
        in project: Project,
        context: ModelContext
    ) {
        var ordered = project.sortedYouTubeBlocks
        ordered.move(fromOffsets: offsets, toOffset: destination)
        apply(order: ordered)
        finish(project, context: context)
    }

    static func shift(_ block: YouTubeBlock, by delta: Int, context: ModelContext) {
        guard let project = block.project else { return }
        var ordered = project.sortedYouTubeBlocks
        guard let index = ordered.firstIndex(where: { $0.id == block.id }) else { return }
        let target = index + delta
        guard ordered.indices.contains(target) else { return }
        ordered.swapAt(index, target)
        apply(order: ordered)
        finish(project, context: context)
    }

    static func toggleCollapse(_ block: YouTubeBlock, context: ModelContext) {
        guard block.kind.isHeader else { return }
        block.isCollapsed.toggle()
        PersistenceActions.save(context)
    }

    static func commitEdits(to block: YouTubeBlock, context: ModelContext) {
        block.touch()
        PersistenceActions.save(context)
    }

    // MARK: Folding

    /// Blocks actually shown, honouring collapsed sections.
    static func visibleBlocks(in blocks: [YouTubeBlock]) -> [YouTubeBlock] {
        var result: [YouTubeBlock] = []
        var hiding = false
        for block in blocks {
            if block.kind.isHeader {
                hiding = block.isCollapsed
                result.append(block)
            } else if !hiding {
                result.append(block)
            }
        }
        return result
    }

    /// How many blocks a section folds away.
    static func childCount(of section: YouTubeBlock, in blocks: [YouTubeBlock]) -> Int {
        guard section.kind.isHeader,
              let start = blocks.firstIndex(where: { $0.id == section.id })
        else { return 0 }
        var count = 0
        for block in blocks[blocks.index(after: start)...] {
            if block.kind.isHeader { break }
            count += 1
        }
        return count
    }

    // MARK: Bridge to the breakdown

    /// Turns a block into a real scene, so it can carry shots, a location and
    /// a shooting day. The block keeps its text and gains a link to the scene.
    @discardableResult
    static func promoteToScene(_ block: YouTubeBlock, context: ModelContext) -> StoryScene? {
        guard let project = block.project, block.kind.canBecomeScene else { return nil }
        if let existing = block.scene { return existing }

        let scene = SceneService.create(
            in: project,
            title: block.displayTitle,
            context: context
        )
        scene.synopsis = block.text
        block.scene = scene
        finish(project, context: context)
        return scene
    }

    static func detachScene(from block: YouTubeBlock, context: ModelContext) {
        block.scene = nil
        block.touch()
        PersistenceActions.save(context)
    }

    // MARK: Starter outline

    /// Blocks proposed when a script is still empty, so the writer never faces
    /// a blank page.
    static func starterOutline(for project: Project, context: ModelContext) {
        guard project.youtubeBlocks.isEmpty else { return }
        let plan: [(YouTubeBlockKind, String)] = [
            (.hook, "Accroche"),
            (.intro, "Intro"),
            (.section, "Chapitre 1"),
            (.aRoll, "Face caméra"),
            (.bRoll, "Illustration"),
            (.callToAction, "Appel à l'action")
        ]
        for (kind, title) in plan {
            append(kind, title: title, to: project, context: context)
        }
    }

    // MARK: Ordering

    static func reindex(_ project: Project) {
        apply(order: project.sortedYouTubeBlocks)
    }

    private static func apply(order: [YouTubeBlock]) {
        for (index, block) in order.enumerated() where block.orderIndex != index {
            block.orderIndex = index
        }
    }

    private static func finish(_ project: Project, context: ModelContext) {
        project.touch()
        PersistenceActions.save(context)
    }
}
