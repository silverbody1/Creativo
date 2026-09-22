import XCTest
@testable import Creativo

/// The formatter is pure, so its rules are tested without a store.
final class ScreenplayFormatterTests: XCTestCase {
    // MARK: Rendering

    func testCharacterAndTransitionAreUppercased() {
        let character = ScreenplayElement(type: .character, text: "noé")
        XCTAssertEqual(character.renderedText, "NOÉ")

        let transition = ScreenplayElement(type: .transition, text: "cut to:")
        XCTAssertEqual(transition.renderedText, "CUT TO:")
    }

    func testParentheticalGetsExactlyOnePairOfParentheses() {
        XCTAssertEqual(ScreenplayElement(type: .parenthetical, text: "à voix basse").renderedText, "(à voix basse)")
        XCTAssertEqual(ScreenplayElement(type: .parenthetical, text: "(à voix basse)").renderedText, "(à voix basse)")
        XCTAssertEqual(ScreenplayElement(type: .parenthetical, text: "").renderedText, "")
    }

    func testActionAndDialogueKeepTheirCasing() {
        XCTAssertEqual(ScreenplayElement(type: .action, text: "Il entre.").renderedText, "Il entre.")
        XCTAssertEqual(ScreenplayElement(type: .dialogue, text: "Tu viens ?").renderedText, "Tu viens ?")
    }

    // MARK: Pagination

    func testEmptyElementTakesNoLine() {
        XCTAssertEqual(ScreenplayFormatter.printedLineCount(for: ScreenplayElement(type: .action, text: "   ")), 0)
    }

    func testNotesAreNeverPrinted() {
        let note = ScreenplayElement(type: .note, text: String(repeating: "x", count: 300))
        XCTAssertEqual(ScreenplayFormatter.printedLineCount(for: note), 0)
        XCTAssertFalse(ScreenplayElementType.note.isPrinted)
    }

    func testActionWrapsAtSixtyOneCharacters() {
        let oneLine = ScreenplayElement(type: .action, text: String(repeating: "a", count: 61))
        // One wrapped line plus the blank line that follows an action.
        XCTAssertEqual(ScreenplayFormatter.printedLineCount(for: oneLine), 2)

        let twoLines = ScreenplayElement(type: .action, text: String(repeating: "a", count: 62))
        XCTAssertEqual(ScreenplayFormatter.printedLineCount(for: twoLines), 3)
    }

    func testDialogueWrapsNarrowerThanAction() {
        let text = String(repeating: "a", count: 70)
        let action = ScreenplayElement(type: .action, text: text)
        let dialogue = ScreenplayElement(type: .dialogue, text: text)
        XCTAssertGreaterThan(
            ScreenplayFormatter.printedLineCount(for: dialogue),
            ScreenplayFormatter.printedLineCount(for: action)
        )
    }

    func testCharacterCueTakesOneLineWithNoBlankAfterIt() {
        let cue = ScreenplayElement(type: .character, text: "NOÉ")
        XCTAssertEqual(ScreenplayFormatter.printedLineCount(for: cue), 1)
    }

    // MARK: Parsing

    func testParseRecognisesACharacterCueFollowedByDialogue() {
        let parsed = ScreenplayFormatter.parse("NOÉ\nTu viens ?")
        XCTAssertEqual(parsed.count, 2)
        XCTAssertEqual(parsed[0].type, .character)
        XCTAssertEqual(parsed[0].text, "NOÉ")
        XCTAssertEqual(parsed[1].type, .dialogue)
        XCTAssertEqual(parsed[1].text, "Tu viens ?")
    }

    func testParseRecognisesParentheticalsAndStripsTheirParentheses() {
        let parsed = ScreenplayFormatter.parse("MAÏA\n(à voix basse)\nIl n'y a pas de vent.")
        XCTAssertEqual(parsed.map(\.type), [.character, .parenthetical, .dialogue])
        XCTAssertEqual(parsed[1].text, "à voix basse")
    }

    func testParseRecognisesTransitions() {
        let parsed = ScreenplayFormatter.parse("CUT TO:")
        XCTAssertEqual(parsed.first?.type, .transition)
    }

    func testParseRecognisesNotes() {
        let parsed = ScreenplayFormatter.parse("[[ vérifier la lumière ]]")
        XCTAssertEqual(parsed.first?.type, .note)
        XCTAssertEqual(parsed.first?.text, "vérifier la lumière")
    }

    func testParseFallsBackToAction() {
        let parsed = ScreenplayFormatter.parse("Un chemin de terre disparaît sous les fougères.")
        XCTAssertEqual(parsed.first?.type, .action)
    }

    func testParseDoesNotMistakeASlugLineForACharacterCue() {
        let parsed = ScreenplayFormatter.parse("INT. STUDIO — NUIT")
        XCTAssertEqual(parsed.first?.type, .action)
    }

    func testParseKeepsEveryNonEmptyParagraph() {
        let source = "Ligne une.\n\n\nLigne deux.\n   \nLigne trois."
        XCTAssertEqual(ScreenplayFormatter.parse(source).count, 3)
    }

    func testParseOfEmptyTextProducesNothing() {
        XCTAssertTrue(ScreenplayFormatter.parse("   \n\n ").isEmpty)
    }

    // MARK: Successors

    func testNaturalSuccessorFollowsTheFormatConventions() {
        XCTAssertEqual(ScreenplayElementType.character.naturalSuccessor, .dialogue)
        XCTAssertEqual(ScreenplayElementType.parenthetical.naturalSuccessor, .dialogue)
        XCTAssertEqual(ScreenplayElementType.dialogue.naturalSuccessor, .action)
        XCTAssertEqual(ScreenplayElementType.action.naturalSuccessor, .action)
    }

    func testEveryElementTypeHasADistinctShortcutDigit() {
        let digits = ScreenplayElementType.allCases.map(\.shortcutDigit)
        XCTAssertEqual(Set(digits).count, ScreenplayElementType.allCases.count)
    }
}
