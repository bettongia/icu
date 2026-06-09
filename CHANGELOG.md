# Changelog

## 0.1.0

Initial release.

### Added

- `Tokenizer` — abstract interface for text segmentation. Implementations return
  only word-like tokens (letters and digits); punctuation and whitespace are
  discarded.

- `IcuTokenizer` — UAX #29 word-boundary segmentation via the system ICU
  library (FFI). Handles non-Latin scripts: CJK, Arabic, Thai, Devanagari, and
  more. Supported platforms:

  | Platform    | Library                                      |
  |-------------|----------------------------------------------|
  | macOS / iOS | `libicucore.dylib` (ships with the OS)       |
  | Android     | `libicuuc.so` (NDK)                          |
  | Linux       | `libicuuc.so.NN` (install `libicu-dev`/`icu`)|
  | Windows     | `icu.dll` (Windows 10+)                      |

  Probes for ICU symbol renaming (e.g. `ubrk_open_76` on Debian Trixie+ and
  Fedora) so no manual configuration is needed.

  Uses `RegExp`-based span classification instead of `ubrk_getRuleStatus()`
  for portability across all supported platforms, including Apple's
  `libicucore` which does not export UAX #29 rule-status tags.

- `RegExpTokenizer` — pure-Dart tokenizer using `RegExp` with Unicode property
  escapes (`\p{L}`, `\p{N}`). Zero FFI dependencies; suitable for English
  prose and common technical identifiers (`mTLS`, `0x8004210B`, etc.).
  Works on every platform, including web.

- `BrowserTokenizer` — UAX #29 word-boundary segmentation via the browser's
  `Intl.Segmenter` API (`dart:js_interop`). Web-only; zero bundle cost.
  Requires Chrome 87+, Firefox 125+, or Safari 16.4+. On native targets the
  conditional import resolves to a stub that throws `UnsupportedError`.

- Conditional export pattern in `lib/betto_icu.dart`: the correct
  `IcuTokenizer` implementation (real FFI or stub) and `BrowserTokenizer`
  implementation (real JS interop or stub) are selected at compile time via
  `dart.library.ffi` and `dart.library.js_interop`.

- `IcuTokenizer.forPlatform(String platform)` — named constructor that loads
  the ICU library for an explicit platform string. Enables tests to exercise
  each library-loading branch without requiring the native OS.

- `bin/tokenize.dart` — command-line tool that tokenizes a string with either
  or both tokenizers (`--icu`, `--regexp`).

- Flutter integration test app (`integration_test_app/`) — runs the full
  contract and UAX #29 test suite on Android and iOS via
  `package:integration_test`.
