# CLAUDE.md — oops for macOS

A native macOS port of [oops](https://github.com/vladvysotsky/oops). Swift +
SwiftUI, no shared code with the Windows version.

**The model is documented once, in the Windows repository's `CLAUDE.md`** —
the expanding scope, what must never come back, and the whole list of traps that
turned out to be bugs. This file holds only what is specific to macOS. When the
two disagree about the model, that one wins.

## Why a rewrite and not shared code

The application is about 90% platform glue: intercepting the keyboard,
emulating input, reading the selection, switching the input source. The only
genuinely portable parts are the layout table and the expanding-scope model —
a few hundred lines. Building a cross-platform abstraction for that would cost
more, forever, than porting it once.

What is shared instead is the **specification**: the tests. Every one of them
describes behaviour that was worked out on real users, and they were ported
before any platform code existed.

## Layout

- `Sources/OopsCore/` — pure logic, **no system frameworks**, Foundation only.
  Builds and tests with `swift test` in seconds, without Xcode and without
  Accessibility permission. Keep it that way: the platform layer cannot be
  tested off a Mac, so everything that can be pure logic must stay pure.
  - `LayoutConverter.swift` — QWERTY ↔ ЙЦУКЕН by key position.
  - `TypingBuffer.swift` — the ribbon of typed characters.
  - `ScopeEditor.swift` — the expanding-scope model.
- `Tests/OopsCoreTests/` — the ported specification.

## Counted in Characters, not UTF-16

One Backspace removes one grapheme cluster, so the erase arithmetic counts
Swift `Character`s. The C# version counted UTF-16 units and needed an explicit
guard for surrogate pairs; here the guard is not needed, but the invariant is
the same — **a transformation must preserve the character count**, or we no
longer know how much is on screen and must not touch the text at all.

## What the Windows APIs become

| Windows | macOS |
|---|---|
| `WH_KEYBOARD_LL` | `CGEvent.tapCreate`, requires Accessibility permission |
| `SendInput` + `KEYEVENTF_UNICODE` | `CGEvent` + `keyboardSetUnicodeString` |
| reading the selection through Ctrl+C | `AXUIElementCopyAttributeValue(kAXSelectedTextAttribute)` |
| `WM_INPUTLANGCHANGEREQUEST` | `TISSelectInputSource` |
| `NotifyIcon` | `MenuBarExtra` (SwiftUI, macOS 13+) |
| `HKCU\...\Run` | `SMAppService.mainApp.register()` |

Two differences worth knowing before writing the platform layer:

- **The selection is readable properly.** The Accessibility API returns the
  selected text directly, so the clipboard round-trip that the Windows version
  is forced into is only a fallback here, for applications with poor AX support.
- **The tap is disabled on timeout, like the Windows hook** — but macOS says so.
  It delivers `kCGEventTapDisabledByTimeout`, and the tap is brought back with
  `CGEvent.tapEnable`. On Windows the same failure is silent and has to be
  discovered by probing. Do not drop that handler: it is the known cause of
  "the program stopped working at some point".

## Two core changes landed on Windows after this port — carry them over

Both are in the Windows repository's `CLAUDE.md`; the Swift core here still has
the older behaviour.

1. **`AutoConvertWithDirection` picks the direction per word**, not per piece,
   and reports the direction of the last word that had one. Without it the
   ordinary mixed case cannot be fixed at all: in
   "Z djn [jxe pfgecnbnm ЬщвудКшыл" the first words were typed in the English
   layout instead of Russian and the last one the other way round, and one
   direction for the whole piece lets the majority of letters win.
2. **The scope continues by content, not only by the clock.** If the buffer is
   still exactly what we emitted, nothing was typed after our edit, so the next
   press continues the same scope however long the user took. Otherwise a slow
   second press started a new session and undid the first one.

## Planned features, and what was learned from keyboop

[keyboop](https://github.com/iffuno/keyboop) solves the same problem on macOS.
Two of its decisions are worth taking:

- **Translation via Apple's on-device Translation framework**, replacing the
  selection in place. Nothing to download, nothing to ship, no second engine —
  the Windows version carries Bergamot and ~45 MB of models only because
  Windows has no equivalent. Requires macOS 15; on 13 and 14 the feature is
  offered but tells the user what it needs.
- **Push-to-talk for dictation**: hold the shortcut, speak, release. Better
  than the Windows toggle, and the reason the Windows version does not do it
  is specific to Windows — its hotkeys are modifier-only chords, where holding
  is indistinguishable from auto-repeat. There is no such constraint here.
  A toggle stays available as an option for long dictation.

Speech recognition stays on **whisper.cpp** (Metal). keyboop also ships
Parakeet through the Neural Engine, which is faster on Apple Silicon — worth
adding later as an option, but not as the base: Whisper is the more reliable of
the two on Russian, and Russian is the primary language here.

## Distribution

Gatekeeper is stricter than SmartScreen: an unsigned build is effectively
unusable on current macOS. Shipping needs an Apple Developer account, a
Developer ID signature and notarisation. Plan for it before promising a release.

The first-run wizard must also walk the user through granting Accessibility
permission — without it the application receives no key events at all and looks
broken, which is exactly the failure the Windows version's wizard exists to
prevent.

## Git

- Commit messages, pull request titles and descriptions are written in English.
- Do not add `Co-Authored-By` trailers.
