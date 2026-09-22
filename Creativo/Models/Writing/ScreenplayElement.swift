import Foundation
import SwiftData

/// One typed line of a screenplay, owned by the scene it belongs to.
///
/// The screenplay is stored as elements rather than as one blob of text so the
/// app can count pages, jump between speakers and export properly. It does not
/// introduce a second scene system: elements hang off the existing
/// `StoryScene`, which stays the single spine of the project.
@Model
final class ScreenplayElement {
    var id: UUID = UUID()
    var type: ScreenplayElementType = ScreenplayElementType.action
    var text: String = ""
    var orderIndex: Int = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var scene: StoryScene?

    init(
        type: ScreenplayElementType = .action,
        text: String = "",
        orderIndex: Int = 0,
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.type = type
        self.text = text
        self.orderIndex = orderIndex
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
}

extension ScreenplayElement {
    var isEmpty: Bool { text.isBlank }

    /// Text as it appears on the page, with the casing the format imposes.
    var renderedText: String {
        switch type {
        case .character, .transition:
            return text.uppercased()
        case .parenthetical:
            let trimmed = text.trimmed
            guard !trimmed.isEmpty else { return trimmed }
            let withoutParens = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "()"))
            return "(\(withoutParens))"
        case .action, .dialogue, .note:
            return text
        }
    }

    func touch(_ date: Date = .now) {
        updatedAt = date
        scene?.touch(date)
    }
}

/// The typed elements a screenplay is made of.
///
/// The scene heading is deliberately absent: it is not free text but the scene
/// itself — its interior/exterior, its location and its time of day — so that
/// the breakdown, the schedule and the budget always agree with the page.
enum ScreenplayElementType: String, Codable, CaseIterable, Identifiable, Sendable {
    case action
    case character
    case dialogue
    case parenthetical
    case transition
    case note

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .action: return "Action"
        case .character: return "Personnage"
        case .dialogue: return "Dialogue"
        case .parenthetical: return "Parenthèse"
        case .transition: return "Transition"
        case .note: return "Note"
        }
    }

    var symbolName: String {
        switch self {
        case .action: return "text.alignleft"
        case .character: return "person"
        case .dialogue: return "quote.bubble"
        case .parenthetical: return "ellipsis.bubble"
        case .transition: return "arrow.right.to.line"
        case .note: return "note.text"
        }
    }

    /// Keyboard shortcut digit, 1 through 6, matching the element bar order.
    var shortcutDigit: Character {
        switch self {
        case .action: return "1"
        case .character: return "2"
        case .dialogue: return "3"
        case .parenthetical: return "4"
        case .transition: return "5"
        case .note: return "6"
        }
    }

    /// What pressing "new element" after this one should produce, following
    /// the conventions every screenwriting tool shares.
    var naturalSuccessor: ScreenplayElementType {
        switch self {
        case .character: return .dialogue
        case .parenthetical: return .dialogue
        case .dialogue: return .action
        case .action, .transition, .note: return .action
        }
    }

    /// Notes are the writer's margin, never part of the printed page.
    var isPrinted: Bool { self != .note }

    /// Characters that fit on one line of a 12 pt Courier page at this indent.
    var charactersPerLine: Int {
        switch self {
        case .action: return 61
        case .dialogue: return 35
        case .character: return 38
        case .parenthetical: return 25
        case .transition: return 20
        case .note: return 61
        }
    }
}
