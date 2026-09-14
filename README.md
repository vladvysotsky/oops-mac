# oops for macOS

> `ghjdthrf njuj rfr 'nj hf,jnftn` → **oops** → `проверка того как это работает`

A native macOS port of [oops](https://github.com/vladvysotsky/oops) — a utility
that fixes text typed in the wrong keyboard layout (RU ↔ EN) and switches its
case, anywhere in the system.

**Early work in progress.** Right now the repository holds the core model and
its tests; nothing runs yet.

## Status

| Part | State |
|---|---|
| Layout table, typing ribbon, expanding scope | ported, under test |
| Keyboard tap, typing emulation, selection | not started |
| Menu bar app, settings | not started |
| Replace in selection | not started |
| Translation, voice input | not started |

## The core idea

The program **never guesses** where the wrong layout began. The user sets the
boundary with repeated hotkey presses: the first fixes the last word, the second
fixes everything typed. Every step is a 1-to-1 transformation of a clearly
delimited piece, and correct text outside it is never touched.

That model, and the reasons behind every decision in it, are documented in the
Windows repository's [CLAUDE.md](https://github.com/vladvysotsky/oops/blob/main/CLAUDE.md).
It is the source of truth for both ports — this one keeps only what is specific
to macOS, in its own [CLAUDE.md](CLAUDE.md).

## Building and testing

`OopsCore` depends on nothing but Foundation, so it builds and tests without
Xcode and without any system permissions:

```bash
swift test
```

That is deliberate. The interesting part of this program is glue against system
APIs that cannot be tested off the machine, so everything that *can* be pure
logic is kept pure and covered by tests.

## Requirements

- macOS 13 for the base features.
- macOS 15 for translation, if Apple's on-device Translation framework is used.
- Voice input works from 13 — whisper.cpp builds natively with Metal.

## License

MIT — see [LICENSE](LICENSE).
