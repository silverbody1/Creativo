import Foundation

/// Turns screenplay elements into printed text and into a page count.
///
/// Pure arithmetic and string work: no SwiftData, no SwiftUI, so every rule
/// here is unit-tested directly.
enum ScreenplayFormatter {
    /// Lines on a standard 12 pt Courier page, margins included.
    static let linesPerPage = 55

    // MARK: Pagination

    /// Lines a single element occupies once wrapped, blank line included.
    static func printedLineCount(for element: ScreenplayElement) -> Int {
        guard element.type.isPrinted else { return 0 }
        let text = element.renderedText.trimmed
        guard !text.isEmpty else { return 0 }

        let perLine = max(element.type.charactersPerLine, 1)
        let wrapped = max(Int(ceil(Double(text.count) / Double(perLine))), 1)

        let blankAfter: Int
        switch element.type {
        case .action, .dialogue, .transition: blankAfter = 1
        case .character, .parenthetical, .note: blankAfter = 0
        }
        return wrapped + blankAfter
    }

    /// Lines a scene occupies, its heading included. A scene with nothing
    /// written counts as zero so an empty project does not show a page.
    static func printedLineCount(for scene: StoryScene) -> Int {
        let body = scene.sortedScreenplayElements.reduce(0) { $0 + printedLineCount(for: $1) }
        guard body > 0 else { return 0 }
        // Heading plus the blank line that follows it.
        return body + 2
    }

    static func printedLineCount(for scenes: [StoryScene]) -> Int {
        scenes.reduce(0) { $0 + printedLineCount(for: $1) }
    }

    /// Estimated length in pages, one decimal being enough to be useful.
    static func pageCount(for scenes: [StoryScene]) -> Double {
        let lines = printedLineCount(for: scenes)
        guard lines > 0 else { return 0 }
        return (Double(lines) / Double(linesPerPage) * 10).rounded() / 10
    }

    /// `2,4 pages` / `1 page` / `—`
    static func pageCountText(for scenes: [StoryScene]) -> String {
        let pages = pageCount(for: scenes)
        guard pages > 0 else { return "—" }
        let formatted = pages.formatted(.number.precision(.fractionLength(0...1)))
        return pages <= 1 ? "\(formatted) page" : "\(formatted) pages"
    }

    // MARK: Plain text

    /// Screenplay of one scene as plain text, used to keep `StoryScene.content`
    /// readable by the rest of the app and by future exports.
    static func plainText(for scene: StoryScene) -> String {
        var lines: [String] = [scene.slugline]
        for element in scene.sortedScreenplayElements {
            let text = element.renderedText.trimmed
            guard !text.isEmpty else { continue }
            lines.append("")
            switch element.type {
            case .note:
                lines.append("[[ \(text) ]]")
            default:
                lines.append(text)
            }
        }
        return lines.joined(separator: "\n")
    }

    static func plainText(for scenes: [StoryScene]) -> String {
        scenes
            .map(plainText(for:))
            .joined(separator: "\n\n")
    }

    // MARK: Import

    /// Best-effort parse of free text into typed elements.
    ///
    /// Used once per scene, when a screenplay written before this phase is
    /// opened in the editor for the first time. It never discards text: a
    /// paragraph it cannot classify becomes an action line.
    static func parse(_ text: String) -> [(type: ScreenplayElementType, text: String)] {
        // In screenplay text every line break starts a new element, so a plain
        // split by newline is both correct and predictable.
        let paragraphs = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")
            .map { $0.trimmed }
            .filter { !$0.isEmpty }

        var result: [(type: ScreenplayElementType, text: String)] = []
        var previous: ScreenplayElementType?

        for paragraph in paragraphs {
            let type = classify(paragraph, previous: previous)
            let cleaned: String
            switch type {
            case .note:
                cleaned = paragraph
                    .trimmingCharacters(in: CharacterSet(charactersIn: "[] "))
            case .parenthetical:
                cleaned = paragraph.trimmingCharacters(in: CharacterSet(charactersIn: "() "))
            default:
                cleaned = paragraph
            }
            result.append((type, cleaned))
            previous = type
        }
        return result
    }

    private static func classify(_ paragraph: String, previous: ScreenplayElementType?) -> ScreenplayElementType {
        if paragraph.hasPrefix("[[") || paragraph.hasPrefix("//") {
            return .note
        }
        if paragraph.hasPrefix("(") && paragraph.hasSuffix(")") {
            return .parenthetical
        }
        if isTransition(paragraph) {
            return .transition
        }
        if isCharacterCue(paragraph) {
            return .character
        }
        if previous == .character || previous == .parenthetical {
            return .dialogue
        }
        return .action
    }

    private static func isTransition(_ paragraph: String) -> Bool {
        guard isUppercased(paragraph) else { return false }
        let known = ["CUT TO", "FADE", "DISSOLVE", "SMASH CUT", "COUPE", "FONDU", "TRANSITION"]
        let upper = paragraph.uppercased()
        return paragraph.hasSuffix(":") || known.contains { upper.hasPrefix($0) }
    }

    private static func isCharacterCue(_ paragraph: String) -> Bool {
        guard isUppercased(paragraph) else { return false }
        guard paragraph.count <= 40 else { return false }
        guard !paragraph.hasSuffix(".") else { return false }
        // A slug line is the scene's business, not a character cue.
        let upper = paragraph.uppercased()
        let sluglinePrefixes = ["INT.", "EXT.", "INT/EXT", "INT./EXT."]
        return !sluglinePrefixes.contains { upper.hasPrefix($0) }
    }

    /// `true` when a paragraph carries no lowercase letter at all.
    private static func isUppercased(_ paragraph: String) -> Bool {
        let letters = paragraph.filter(\.isLetter)
        guard !letters.isEmpty else { return false }
        return !letters.contains { $0.isLowercase }
    }
}
