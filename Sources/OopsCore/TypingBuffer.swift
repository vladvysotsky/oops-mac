import Foundation

/// The ribbon of characters the user has typed since the last reset.
///
/// No dictionaries and no heuristics — just "what was typed". It can report
/// where the Nth word from the end begins, and the expanding-scope model is
/// built on that: the first hotkey press fixes the last word, the second fixes
/// everything.
///
/// It is cleared on Enter/Tab/Esc/arrows/Delete, on a mouse click, on a window
/// change, on a manual layout switch and after an idle timeout.
///
/// **Counted in Characters, not in UTF-16 units.** A Character in Swift is a
/// grapheme cluster, and one Backspace deletes exactly one of those. Counting
/// anything else would make the erase arithmetic wrong for emoji and for
/// letters with combining marks.
public final class TypingBuffer {

    private let lock = NSLock()
    private var characters: [Character] = []
    private var lastInput = Date()

    /// How long the buffer stays valid with no typing.
    public var idleTimeout: TimeInterval = 30

    public init() {}

    public var snapshot: String {
        lock.lock()
        defer { lock.unlock() }
        evictIfIdle()
        return String(characters)
    }

    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        evictIfIdle()
        return characters.count
    }

    public func append(_ character: Character) {
        lock.lock()
        defer { lock.unlock() }
        evictIfIdle()
        characters.append(character)
        lastInput = Date()
    }

    public func backspace() {
        lock.lock()
        defer { lock.unlock() }
        evictIfIdle()
        if !characters.isEmpty { characters.removeLast() }
        lastInput = Date()
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        characters.removeAll()
        lastInput = Date()
    }

    /// Replaces the contents — used after we have rewritten the text on screen
    /// ourselves, so the ribbon keeps matching what the user can see.
    public func reset(to text: String) {
        lock.lock()
        defer { lock.unlock() }
        characters = Array(text)
        lastInput = Date()
    }

    /// Must be called with the lock held.
    private func evictIfIdle() {
        if Date().timeIntervalSince(lastInput) > idleTimeout {
            characters.removeAll()
        }
    }

    /// Index where the `wordsFromEnd`-th word from the end begins.
    ///
    /// 1 → the start of the last word, 2 → the start of the one before it. If
    /// there are fewer words than asked for, returns 0 — the whole string. A
    /// word is a run of non-whitespace characters.
    public static func startOfLastWords(_ text: String, wordsFromEnd: Int) -> Int {
        let characters = Array(text)
        if characters.isEmpty || wordsFromEnd <= 0 { return characters.count }

        var index = characters.count
        var found = 0

        while index > 0 {
            // Trailing whitespace is not a word: "hello " still ends on "hello".
            while index > 0 && characters[index - 1].isWhitespace { index -= 1 }
            if index == 0 { break }

            let wordEnd = index
            while index > 0 && !characters[index - 1].isWhitespace { index -= 1 }
            found += 1
            if found == wordsFromEnd { return index }
            if wordEnd == index { break }   // guard against looping forever
        }

        return 0
    }

    /// How many words the string holds.
    public static func countWords(_ text: String) -> Int {
        var words = 0
        var insideWord = false
        for character in text {
            if character.isWhitespace {
                insideWord = false
            } else if !insideWord {
                insideWord = true
                words += 1
            }
        }
        return words
    }
}
