import Foundation

/// What needs to happen to the text on screen.
///
/// The case is `nothing` rather than `none` on purpose — see the note on
/// `LayoutDirection`.
public struct Edit: Equatable {
    /// How many characters to remove with Backspace.
    public let eraseCount: Int
    /// What to type in their place.
    public let text: String
    /// Which way to switch the system input source (layout steps only).
    public let direction: LayoutDirection
    /// What the typing buffer must become afterwards.
    public let newBufferContent: String

    public var isEmpty: Bool { eraseCount == 0 && text.isEmpty }

    public static let nothing = Edit(
        eraseCount: 0, text: "", direction: .unchanged, newBufferContent: ""
    )
}

/// The expanding-scope model.
///
/// The program **never guesses** where the wrong layout began. The user sets the
/// boundary with repeated hotkey presses:
///   1st press — the last word,
///   2nd press — everything that was typed.
///
/// Two steps, not one word at a time: on a five-word phrase word-by-word
/// expansion would need five presses, and nobody ever pressed that far. In
/// practice either the last word is mangled or the whole thing is.
///
/// Every step is a blunt 1-to-1 transformation of a clearly delimited piece. No
/// dictionaries, no guesses. Correct text outside the scope is never touched.
///
/// The property everything rests on: both layout conversion and case switching
/// **preserve the number of characters**. So "how many characters are on screen
/// between the start of the scope and the caret" always equals
/// `original.count - scopeStart`, no matter how many times we have already
/// rewritten the text.
public final class ScopeEditor {

    /// How long a following press keeps expanding the same scope.
    public var expandWindow: TimeInterval = 2

    private enum Kind {
        case none
        case layout
        case letterCase
    }

    // The keyboard tap calls resetSession from its own thread, while the steps
    // run on the main one.
    private let lock = NSLock()
    private var original = ""
    private var lastPress = Date.distantPast
    private var step = 0                // 0 — no session, 1 — last word, 2 — everything
    private var kind = Kind.none

    public init() {}

    /// The layout hotkey was pressed.
    public func nextLayoutStep(buffer: String, now: Date = Date()) -> Edit {
        next(kind: .layout, buffer: buffer, now: now)
    }

    /// The case hotkey was pressed.
    public func nextCaseStep(buffer: String, now: Date = Date()) -> Edit {
        next(kind: .letterCase, buffer: buffer, now: now)
    }

    /// Break the expansion — the user typed something new, clicked, and so on.
    public func resetSession() {
        lock.lock()
        defer { lock.unlock() }
        resetLocked()
    }

    private func resetLocked() {
        kind = .none
        step = 0
        original = ""
    }

    private func next(kind requestedKind: Kind, buffer: String, now: Date) -> Edit {
        lock.lock()
        defer { lock.unlock() }

        let continuing = kind == requestedKind
            && step > 0
            && now.timeIntervalSince(lastPress) <= expandWindow

        if !continuing {
            // A new session: freeze whatever is in the buffer as the reference.
            original = buffer
            step = 0
            kind = requestedKind
        }

        if original.isEmpty || TypingBuffer.countWords(original) == 0 {
            resetLocked()
            return .nothing
        }

        let nextStep = step + 1

        // Step 1 is the last word, step 2 is everything typed.
        let startOfLastWord = TypingBuffer.startOfLastWords(original, wordsFromEnd: 1)
        let scopeStart = nextStep == 1 ? startOfLastWord : 0

        // Nowhere left to expand: there are only two steps, and on a one-word
        // buffer the second would capture exactly the same piece.
        let exhausted = nextStep > 2 || (nextStep == 2 && scopeStart == startOfLastWord)
        if exhausted {
            // The timestamp is deliberately NOT updated. Otherwise repeated
            // presses keep extending the expansion window forever, and instead
            // of starting a new session the user gets complete silence — which
            // reads as "the hotkey does not work".
            step = 2
            return .nothing
        }

        lastPress = now
        step = nextStep

        let characters = Array(original)
        let scope = String(characters[scopeStart...])

        let converted: String
        var direction = LayoutDirection.unchanged
        if requestedKind == .layout {
            let result = LayoutConverter.autoConvert(scope)
            converted = result.result
            direction = result.direction
        } else {
            converted = ScopeEditor.toggleCase(scope)
        }

        // All of the erase arithmetic depends on length being preserved. If the
        // transformation changed it anyway (exotic Unicode), we no longer know
        // how many characters are on screen — leaving the text alone is safer.
        if converted.count != scope.count {
            resetLocked()
            return .nothing
        }

        let eraseCount = characters.count - scopeStart
        let newBuffer = String(characters[..<scopeStart]) + converted

        return Edit(
            eraseCount: eraseCount,
            text: converted,
            direction: direction,
            newBufferContent: newBuffer
        )
    }

    /// Any uppercase present → everything goes lower, otherwise everything goes
    /// upper.
    ///
    /// Swift's `lowercased()`/`uppercased()` use Unicode default casing and do
    /// not consult the user's locale. That is what we want: locale-aware rules
    /// (the Turkish dotless "i" and friends) would make the result depend on
    /// system settings.
    public static func toggleCase(_ text: String) -> String {
        for character in text where character.isUppercase {
            return text.lowercased()
        }
        return text.uppercased()
    }
}
