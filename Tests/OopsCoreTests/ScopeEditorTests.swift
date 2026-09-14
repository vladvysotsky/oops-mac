import XCTest
@testable import OopsCore

final class ScopeEditorTests: XCTestCase {

    /// A fixed moment. The absolute value means nothing — only the offsets do.
    private let t0 = Date(timeIntervalSince1970: 1_767_268_800)

    func testFirstPressConvertsOnlyTheLastWord() {
        let editor = ScopeEditor()
        // "привет ghbdtn" — one correct Russian word and one typed in EN.
        let edit = editor.nextLayoutStep(buffer: "привет ghbdtn", now: t0)

        XCTAssertEqual(edit.eraseCount, 6)            // the length of "ghbdtn"
        XCTAssertEqual(edit.text, "привет")
        XCTAssertEqual(edit.newBufferContent, "привет привет")
    }

    func testSecondPressCoversTheWholeBuffer() {
        let editor = ScopeEditor()
        let typed = "ghjdthrf njuj rfr 'nj hf,jnftn"

        let first = editor.nextLayoutStep(buffer: typed, now: t0)
        XCTAssertEqual(first.text, "работает")
        XCTAssertEqual(first.eraseCount, 8)

        // A second press within the window takes everything at once.
        let second = editor.nextLayoutStep(
            buffer: first.newBufferContent, now: t0.addingTimeInterval(0.4)
        )
        XCTAssertEqual(second.text, "проверка того как это работает")
        XCTAssertEqual(second.eraseCount, typed.count)
        XCTAssertEqual(second.newBufferContent, "проверка того как это работает")
    }

    func testThirdPressDoesNothingBecauseTheScopeAlreadyCoversEverything() {
        let editor = ScopeEditor()
        let typed = "ghbdtn rfr ltkf"

        let first = editor.nextLayoutStep(buffer: typed, now: t0)
        let second = editor.nextLayoutStep(
            buffer: first.newBufferContent, now: t0.addingTimeInterval(0.3)
        )
        XCTAssertEqual(second.text, "привет как дела")

        let third = editor.nextLayoutStep(
            buffer: second.newBufferContent, now: t0.addingTimeInterval(0.6)
        )
        XCTAssertTrue(third.isEmpty)
    }

    func testPressAfterTheWindowExpiresStartsANewScopeAtTheLastWord() {
        let editor = ScopeEditor()
        editor.expandWindow = 2

        let first = editor.nextLayoutStep(buffer: "ghbdtn rfr ltkf", now: t0)
        XCTAssertEqual(first.text, "дела")

        // More than the window has passed — the last word again, of the new text.
        let later = editor.nextLayoutStep(
            buffer: first.newBufferContent, now: t0.addingTimeInterval(5)
        )
        XCTAssertEqual(later.text, "ltkf")   // "дела" back to EN
        XCTAssertEqual(later.eraseCount, 4)
    }

    func testExpandingBeyondTheWordCountDoesNothingMore() {
        let editor = ScopeEditor()
        let first = editor.nextLayoutStep(buffer: "vfvf", now: t0)
        XCTAssertEqual(first.text, "мама")

        // There was only one word — the second step would take the same piece.
        let second = editor.nextLayoutStep(
            buffer: first.newBufferContent, now: t0.addingTimeInterval(0.2)
        )
        XCTAssertTrue(second.isEmpty)
    }

    func testCaseStepUsesTheSameScopeModel() {
        let editor = ScopeEditor()
        let first = editor.nextCaseStep(buffer: "привет мир", now: t0)
        XCTAssertEqual(first.text, "МИР")

        // The second step takes the whole text, recomputed from the frozen
        // original ("привет мир"), not from what is already on screen.
        let second = editor.nextCaseStep(
            buffer: first.newBufferContent, now: t0.addingTimeInterval(0.3)
        )
        XCTAssertEqual(second.text, "ПРИВЕТ МИР")
        XCTAssertEqual(second.eraseCount, 10)
    }

    func testSwitchingHotkeyKindStartsAFreshScope() {
        let editor = ScopeEditor()
        let layout = editor.nextLayoutStep(buffer: "ghbdtn rfr", now: t0)
        XCTAssertEqual(layout.text, "как")

        // A different hotkey means a new session — the last word again.
        let casing = editor.nextCaseStep(
            buffer: layout.newBufferContent, now: t0.addingTimeInterval(0.2)
        )
        XCTAssertEqual(casing.text, "КАК")
    }

    func testExpansionSurvivesSlowStepsWhenPressesAreTimedByKeyDown() {
        // Regression: the moment of the press must be recorded in the key
        // handler, not after waiting for modifiers and typing character by
        // character. Otherwise our own delay eats the expansion window on long
        // words.
        let editor = ScopeEditor()
        editor.expandWindow = 2
        let typed = "ghbdtn rfr ltkf"

        let first = editor.nextLayoutStep(buffer: typed, now: t0)
        XCTAssertEqual(first.text, "дела")

        let second = editor.nextLayoutStep(
            buffer: first.newBufferContent, now: t0.addingTimeInterval(1.5)
        )
        XCTAssertEqual(second.text, "привет как дела")
    }

    func testResetSessionForcesTheNextPressToStartOver() {
        let editor = ScopeEditor()
        let first = editor.nextLayoutStep(buffer: "ghbdtn rfr ltkf", now: t0)
        editor.resetSession()

        let second = editor.nextLayoutStep(
            buffer: first.newBufferContent, now: t0.addingTimeInterval(0.1)
        )
        XCTAssertEqual(second.eraseCount, 4)   // one word again, not two
    }

    func testHammeringAnExhaustedScopeDoesNotFreezeTheExpandWindow() {
        // Regression: an empty step must not extend the expansion window.
        // Otherwise someone jabbing the hotkey once a second stays in "nowhere
        // left to expand" forever and sees no reaction at all.
        let editor = ScopeEditor()
        editor.expandWindow = 2

        let first = editor.nextCaseStep(buffer: "привет мир", now: t0)
        XCTAssertEqual(first.text, "МИР")

        let second = editor.nextCaseStep(
            buffer: first.newBufferContent, now: t0.addingTimeInterval(0.3)
        )
        XCTAssertEqual(second.text, "ПРИВЕТ МИР")

        // The scope is fully expanded — these presses stay silent…
        XCTAssertTrue(editor.nextCaseStep(
            buffer: second.newBufferContent, now: t0.addingTimeInterval(0.9)
        ).isEmpty)
        XCTAssertTrue(editor.nextCaseStep(
            buffer: second.newBufferContent, now: t0.addingTimeInterval(1.6)
        ).isEmpty)

        // …but the countdown runs from the last EFFECTIVE step (0.3 s), so two
        // seconds after that a new session begins.
        let again = editor.nextCaseStep(
            buffer: second.newBufferContent, now: t0.addingTimeInterval(2.4)
        )
        XCTAssertEqual(again.text, "мир")   // "МИР" back to lower case
    }

    func testToggleCaseLowersWhenAnythingIsUpper() {
        XCTAssertEqual(ScopeEditor.toggleCase("Hello"), "hello")
        XCTAssertEqual(ScopeEditor.toggleCase("hello"), "HELLO")
        XCTAssertEqual(ScopeEditor.toggleCase("Привет Мир"), "привет мир")
        XCTAssertEqual(ScopeEditor.toggleCase("привет мир"), "ПРИВЕТ МИР")
    }

    func testConversionPreservesLengthSoTheEraseCountStaysCorrect() {
        // The whole erase arithmetic rests on this property.
        let editor = ScopeEditor()
        let edit = editor.nextLayoutStep(buffer: "crf;b ult dpznm", now: t0)
        XCTAssertEqual(edit.eraseCount, edit.text.count)
    }
}
