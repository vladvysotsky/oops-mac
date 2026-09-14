import XCTest
@testable import OopsCore

final class TypingBufferTests: XCTestCase {

    func testAppendAndBackspaceTrackWhatWasTyped() {
        let buffer = TypingBuffer()
        for character in "abc" { buffer.append(character) }
        XCTAssertEqual(buffer.snapshot, "abc")

        buffer.backspace()
        XCTAssertEqual(buffer.snapshot, "ab")
    }

    func testClearEmptiesTheBuffer() {
        let buffer = TypingBuffer()
        buffer.append("x")
        buffer.clear()
        XCTAssertEqual(buffer.count, 0)
    }

    func testResetReplacesTheContents() {
        // Used after we rewrite the text on screen ourselves: the ribbon has to
        // keep matching what the user can see.
        let buffer = TypingBuffer()
        for character in "ghbdtn" { buffer.append(character) }
        buffer.reset(to: "привет")
        XCTAssertEqual(buffer.snapshot, "привет")
    }

    func testStartOfLastWordsFindsWordBoundaries() {
        let text = "привет как дела"
        XCTAssertEqual(TypingBuffer.startOfLastWords(text, wordsFromEnd: 1), 11)  // "дела"
        XCTAssertEqual(TypingBuffer.startOfLastWords(text, wordsFromEnd: 2), 7)   // "как дела"
        XCTAssertEqual(TypingBuffer.startOfLastWords(text, wordsFromEnd: 3), 0)   // everything
        XCTAssertEqual(TypingBuffer.startOfLastWords(text, wordsFromEnd: 9), 0)   // more than there are
    }

    func testTrailingSpaceIsNotAWord() {
        XCTAssertEqual(TypingBuffer.startOfLastWords("привет как дела ", wordsFromEnd: 1), 11)
    }

    func testCountWordsCountsRunsOfNonWhitespace() {
        XCTAssertEqual(TypingBuffer.countWords(""), 0)
        XCTAssertEqual(TypingBuffer.countWords("one"), 1)
        XCTAssertEqual(TypingBuffer.countWords("  one   two  "), 2)
        XCTAssertEqual(TypingBuffer.countWords("a b c d"), 4)
    }

    func testCountingIsInGraphemeClusters() {
        // One Backspace removes one grapheme cluster, so the erase arithmetic
        // has to be counted the same way. The C# version counted UTF-16 units
        // and needed an explicit guard for surrogate pairs.
        let buffer = TypingBuffer()
        buffer.reset(to: "привет 👨‍👩‍👧")
        XCTAssertEqual(buffer.count, 8)
    }
}
