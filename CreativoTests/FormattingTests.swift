import SwiftUI
import XCTest
@testable import Creativo

final class FormattingTests: XCTestCase {
    func testTimecodeUsesMinutesAndSeconds() {
        XCTAssertEqual(AppFormat.timecode(0), "00:00")
        XCTAssertEqual(AppFormat.timecode(59), "00:59")
        XCTAssertEqual(AppFormat.timecode(95), "01:35")
        XCTAssertEqual(AppFormat.timecode(3_661), "1:01:01")
    }

    func testTimecodeClampsNegativeValues() {
        XCTAssertEqual(AppFormat.timecode(-10), "00:00")
    }

    func testDurationReadsAsText() {
        XCTAssertEqual(AppFormat.duration(0), "—")
        XCTAssertEqual(AppFormat.duration(45), "45 s")
        XCTAssertEqual(AppFormat.duration(90), "1 min 30 s")
        XCTAssertEqual(AppFormat.duration(3_600), "1 h")
    }

    func testFrameRateDropsTrailingZeros() {
        XCTAssertEqual(AppFormat.frameRate(25), "25 fps")
        XCTAssertEqual(AppFormat.frameRate(24), "24 fps")
        XCTAssertTrue(AppFormat.frameRate(23.976).hasSuffix("fps"))
        XCTAssertTrue(AppFormat.frameRate(23.976).contains("23"))
    }

    func testCountPicksSingularPluralOrZero() {
        XCTAssertEqual(AppFormat.count(0, singular: "scène", plural: "scènes", zero: "Aucune scène"), "Aucune scène")
        XCTAssertEqual(AppFormat.count(1, singular: "scène", plural: "scènes", zero: "Aucune scène"), "1 scène")
        XCTAssertEqual(AppFormat.count(4, singular: "scène", plural: "scènes", zero: "Aucune scène"), "4 scènes")
    }

    func testBlankDetectsWhitespaceOnlyStrings() {
        XCTAssertTrue("".isBlank)
        XCTAssertTrue("   \n ".isBlank)
        XCTAssertFalse(" a ".isBlank)
        XCTAssertEqual(" a ".trimmed, "a")
    }

    func testSearchIgnoresCaseAndAccents() {
        XCTAssertTrue("LISIÈRE".matches("lisiere"))
        XCTAssertTrue("Studio Est".matches("STUDIO"))
        XCTAssertFalse("Studio Est".matches("rooftop"))
        XCTAssertTrue("anything".matches("   "))
    }

    func testGreetingFollowsTheTimeOfDay() {
        let calendar = Calendar(identifier: .gregorian)
        func date(hour: Int) -> Date {
            var components = DateComponents()
            components.year = 2026
            components.month = 3
            components.day = 12
            components.hour = hour
            return calendar.date(from: components) ?? Date()
        }

        XCTAssertEqual(HomeView.greetingText(now: date(hour: 8), calendar: calendar), "Bonjour")
        XCTAssertEqual(HomeView.greetingText(now: date(hour: 14), calendar: calendar), "Bon après-midi")
        XCTAssertEqual(HomeView.greetingText(now: date(hour: 22), calendar: calendar), "Bonsoir")
        XCTAssertEqual(HomeView.greetingText(now: date(hour: 3), calendar: calendar), "Bonsoir")
    }
}
