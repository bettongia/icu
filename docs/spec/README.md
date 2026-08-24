---
title: Technical Specification
subtitle: betto_icu
toc-title: "Contents"
...

- **Package:** `betto_icu`
- **Version:** 0.1.0
- **Dart SDK:** `^3.13.0`
- **License:** Apache 2.0

# Purpose and scope

`betto_icu` is a Dart package that segments Unicode text into word-like tokens.
It provides a single, narrow `Tokenizer` interface with three implementations
that collectively cover every platform a Dart or Flutter application may target:

- native platforms (macOS, iOS, Android, Linux, Windows) via ICU FFI;
- the browser via `Intl.Segmenter`; and
- all platforms, including older browsers, via a pure-Dart fallback.

The intended downstream consumer is a search-indexing pipeline. The `tokenise`
method performs segmentation only: it returns the word-like spans of the input
string and discards whitespace and punctuation boundaries. Normalisation (case
folding, diacritics, stemming) is handled by the pipeline that calls the
tokenizer, not by this package.

## Design goals

| Goal                                  | Rationale                                                                                                                                                  |
| ------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| UAX #29 compliance                    | Correct word boundaries for CJK, Thai, Arabic, and other non-Latin scripts require a Unicode Text Segmentation implementation, not a regular expression.   |
| No bundled ICU data                   | ICU ships with every major operating system and every major browser. Bundling a copy would add several megabytes to app size unnecessarily.                |
| Identical public API across platforms | Callers select the tokenizer at construction time; the segmentation call is `tokenise(String)` on every target.                                            |
| Fail-loud on wrong platform           | Constructing an implementation unavailable on the current platform throws `UnsupportedError` immediately rather than silently returning incorrect results. |
| Zero Flutter dependency               | The package is pure Dart. Flutter integration tests live in a separate `integration_test_app/` directory and are not part of the published package.        |

# Public API

The package exports a single library, `package:betto_icu/betto_icu.dart`, which
re-exports four public names.

## `Tokenizer` (abstract interface class)

```dart
abstract interface class Tokenizer {
  List<String> tokenise(String text);
}
```

The narrow interface intentionally omits locale, normalisation, and any
configuration. The sole method contract:

- An empty `text` must return an empty list without error.
- Only word-like spans (those containing at least one Unicode letter `\p{L}` or
  digit `\p{N}`) are returned.
- Whitespace, punctuation, and other non-word spans are discarded.
- The returned list must not contain empty strings.

## `IcuTokenizer`

FFI-backed implementation using the OS-provided ICU break-iterator library.
Available on native platforms (`dart:ffi` present). Throws `UnsupportedError` at
construction time on web.

```dart
// Default constructor — loads the system ICU library for the current platform.
IcuTokenizer()

// Test constructor — forces the named platform's library-loading branch.
IcuTokenizer.forPlatform(String platform)
```

## `RegExpTokenizer`

Pure-Dart implementation. Available on all platforms including web. Suitable for
English prose and common technical identifiers. Not suitable for non-Latin
scripts.

```dart
const RegExpTokenizer()
```

The class is declared `const`; a single shared instance is sufficient.

## `BrowserTokenizer`

JS-interop-backed implementation using the browser's `Intl.Segmenter` API.
Available on web targets (`dart:js_interop` present). Throws `UnsupportedError`
at construction time on native platforms.

```dart
// locale defaults to '' (browser default locale).
BrowserTokenizer([String locale = ''])
```

Passing an explicit BCP 47 locale tag (e.g. `'ja'`) biases word-breaking rules
toward that language where the browser's ICU engine distinguishes them.

# Conditional exports — the platform dispatch mechanism

`lib/betto_icu.dart` uses Dart's conditional export syntax to select the correct
implementation file at compile time:

```dart
export 'src/icu_tokenizer_stub.dart'
    if (dart.library.ffi) 'src/icu_tokenizer.dart'
    show IcuTokenizer;

export 'src/browser_tokenizer_stub.dart'
    if (dart.library.js_interop) 'src/browser_tokenizer.dart'
    show BrowserTokenizer;
```

The condition `dart.library.ffi` is true on native platforms (macOS, iOS,
Android, Linux, Windows) and false on web. The condition
`dart.library.js_interop` is true on web and false on native platforms. Each
implementation has a corresponding stub file that satisfies the type system on
the platform where the real implementation is unavailable:

| Platform | `IcuTokenizer` source              | `BrowserTokenizer` source              |
| -------- | ---------------------------------- | -------------------------------------- |
| Native   | `icu_tokenizer.dart` (real)        | `browser_tokenizer_stub.dart` (throws) |
| Web      | `icu_tokenizer_stub.dart` (throws) | `browser_tokenizer.dart` (real)        |

`RegExpTokenizer` is compiled unconditionally on all platforms; it has no stub.

The stub files mirror the constructor signatures of the real implementations so
that the compiler accepts call sites on both platforms. The stubs throw
`UnsupportedError` at runtime if a constructor is called.

# `IcuTokenizer` — FFI implementation

## ICU library location by platform

| Platform    | Library name                                                                     | Notes                                                                                                                      |
| ----------- | -------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| macOS / iOS | `libicucore.dylib`                                                               | Ships with the OS; a single monolithic library.                                                                            |
| Android     | `libicuuc.so`                                                                    | Provided by the NDK at the stable ABI.                                                                                     |
| Linux       | `libicuuc.so` → `libicuuc.so.76` → `.74` → `.73` → `.72` → `.70` → `.67` → `.66` | Unversioned symlink requires the `-dev` package; fallback through versioned names covers Debian, Ubuntu, Arch, and Fedora. |
| Windows     | `icu.dll` → `icuuc.dll`                                                          | Bundled with Windows 10+.                                                                                                  |

`_openIcuLibrary()` iterates the candidate list for each platform. On macOS and
Android there is only one name; on Linux and Windows the function tries each
candidate in order and returns the first that loads successfully. If all
candidates fail, it throws `UnsupportedError` with a human-readable remediation
message.

## ICU symbol-suffix resolution

Some Linux distributions (Debian Trixie+, Fedora) compile ICU with symbol
renaming enabled, exporting `ubrk_open` as `ubrk_open_76` (where `76` is the ICU
major version). Older distributions and Apple's `libicucore` export the symbols
without a version suffix.

After the library is loaded, `_icuSymbolSuffix()` probes for `ubrk_open`
followed by `ubrk_open_NN` for versions 76 down to 64 (inclusive). It returns
the first suffix for which the lookup succeeds. The returned suffix is then
appended to `ubrk_open`, `ubrk_next`, and `ubrk_close` when the FFI bindings are
resolved.

## FFI bindings

Three ICU functions are bound:

| C function                                   | Dart binding | Purpose                                                                    |
| -------------------------------------------- | ------------ | -------------------------------------------------------------------------- |
| `ubrk_open(type, locale, text, len, status)` | `_UbrkOpen`  | Allocate a `UBreakIterator` for word-boundary analysis (`UBRK_WORD = 2`).  |
| `ubrk_next(bi)`                              | `_UbrkNext`  | Advance to the next boundary; returns the byte offset or `UBRK_DONE` (−1). |
| `ubrk_close(bi)`                             | `_UbrkClose` | Release the iterator.                                                      |

The bindings are resolved once at construction time via
`DynamicLibrary.lookupFunction`. The `DynamicLibrary` reference is stored as a
field to prevent the OS from unloading the library while the tokenizer is alive.

## `tokenise` call sequence

1. Return `const []` immediately if `text.isEmpty`.
2. Allocate a native `Uint16` buffer of `text.codeUnits.length` elements via
   `calloc`, and a separate `Int32` cell for the ICU error code.
3. Copy the Dart string's UTF-16 code units into the native buffer element by
   element. Dart strings are natively UTF-16; `String.codeUnits` yields the
   correct `uint16_t` values, including surrogate pairs for supplementary
   characters.
4. Call `ubrk_open(UBRK_WORD, nullptr, buf, len, &status)`. Passing `nullptr`
   for the locale selects ICU's root locale, which is sufficient for
   script-level word-boundary rules.
5. Check `status`: ICU `UErrorCode` values `< 0` are non-fatal warnings; `= 0`
   is success; `> 0` are fatal errors that raise `StateError`.
6. Iterate with `ubrk_next` until it returns `UBRK_DONE`. Each call returns the
   end offset of the next span; the start offset of each span is the end offset
   of the previous one (beginning at zero).
7. For each span, extract the substring from the original Dart `String`.
8. Discard spans that contain no letter or digit character (punctuation-only and
   whitespace spans).
9. Strip any leading or trailing non-word characters from the remaining spans.
   Some ICU builds, including Apple's `libicucore`, group adjacent punctuation
   into the same span as the adjacent word (e.g. `"Hello,"` rather than
   `"Hello"` + `","`). The strip step normalises this.
10. Discard the span if it is empty after stripping.
11. Close the iterator with `ubrk_close` in a `finally` block.
12. Free both native buffers in a `finally` block.

## Span classification — why not `ubrk_getRuleStatus`

UAX #29 defines rule-status codes that classify each span as a word, number,
kana, ideo, or non-word boundary. The standard ICU API exposes these codes via
`ubrk_getRuleStatus()`. This package does not use that function because Apple's
`libicucore` does not include the UAX #29 rule-status tags in its compiled word
break rules: the function returns `0` for all spans regardless of content,
making it impossible to distinguish word spans from whitespace spans on macOS
and iOS.

Instead, span classification uses a Dart `RegExp` with the Unicode flag:

```dart
static final _hasWordChar = RegExp(r'[\p{L}\p{N}]', unicode: true);
```

This approach is portable across all supported platforms and does not depend on
ICU's internal rule tables.

# `RegExpTokenizer` — pure-Dart implementation

The `RegExpTokenizer` compiles a single static `RegExp` pattern at class load
time:

```dart
static final _wordPattern = RegExp(
  r"[\p{L}\p{N}][\p{L}\p{N}_'\-]*[\p{L}\p{N}]|[\p{L}\p{N}]",
  unicode: true,
);
```

The pattern matches:

- **Single-character tokens** — any Unicode letter or digit.
- **Multi-character tokens** — a letter or digit, followed by any sequence of
  letters, digits, underscores (`_`), apostrophes (`'`), or hyphens (`-`),
  ending in a letter or digit.

The alternation prevents apostrophes and hyphens from appearing at the start or
end of a token, so `"don't"` → `["don't"]` but `"-word-"` → `["word"]`.

Dart's `\w` shorthand matches only ASCII `[a-zA-Z0-9_]`. The explicit
`\p{L}\p{N}` character classes with `unicode: true` correctly match accented
Latin characters (é, ü, ñ) and other Unicode letters, making the tokenizer
suitable for European languages even though it cannot handle scripts that lack
whitespace word delimiters.

`tokenise` calls `_wordPattern.allMatches(text)` and maps the matches to
strings. The result list uses `growable: false` to avoid over-allocation. On
empty input the method returns the same `const []` instance without calling the
engine.

# `BrowserTokenizer` — JavaScript interop implementation

## `Intl.Segmenter` bindings

The browser implementation uses `dart:js_interop` extension types to call the
Web Platform's `Intl.Segmenter` API:

```
Intl.Segmenter(locales, { granularity: 'word' })
  .segment(text)          → Segments iterable
Array.from(segments)     → SegmentData[]
SegmentData.isWordLike   → bool
SegmentData.segment      → string
```

The `_arrayFrom` helper calls `Array.from()` from JavaScript to convert the
`Segments` iterable (which is not a JavaScript array and has no `length`
property) into an indexed `JSArray<_SegmentData>` that can be iterated from
Dart.

## Locale handling

The `BrowserTokenizer` constructor accepts an optional BCP 47 locale tag. When
the locale is the empty string (the default), the locales array passed to
`Intl.Segmenter` is empty, which causes the browser to select its default
locale. This matches the documented behaviour of all `Intl` APIs. Passing a
non-empty locale wraps it in a single-element array.

## Browser compatibility

| Browser           | Minimum version |
| ----------------- | --------------- |
| Chrome / Chromium | 87              |
| Firefox           | 125             |
| Safari            | 16.4            |

All three browsers use V8, SpiderMonkey, or JavaScriptCore respectively, each
with a bundled ICU library. The `Intl.Segmenter` API exposes that ICU data
through a standard interface, so the word-breaking quality is equivalent to
`IcuTokenizer` on native platforms.

# Platform support matrix

The following table summarises which tokenizer is available on each compilation
target:

| Target  | `IcuTokenizer`       | `RegExpTokenizer` | `BrowserTokenizer`   |
| ------- | -------------------- | ----------------- | -------------------- |
| macOS   | ✓ (libicucore.dylib) | ✓                 | ✗ (UnsupportedError) |
| iOS     | ✓ (libicucore.dylib) | ✓                 | ✗                    |
| Android | ✓ (libicuuc.so)      | ✓                 | ✗                    |
| Linux   | ✓ (libicuuc.so.NN)   | ✓                 | ✗                    |
| Windows | ✓ (icu.dll)          | ✓                 | ✗                    |
| Web     | ✗ (UnsupportedError) | ✓                 | ✓ (Intl.Segmenter)   |

# Build system

The `Makefile` at the repository root defines all development and CI tasks. The
full pipeline is:

```
make clean prepare license_check format analyze test coverage site
```

| Target           | Command                                                                                                    | Description                                                                                       |
| ---------------- | ---------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| `prepare`        | `dart pub global activate coverage && dart pub get`                                                        | Activates the `coverage` tool and resolves dependencies.                                          |
| `license_check`  | `addlicense --check` via `addlicense_config.txt`                                                           | Verifies Apache 2.0 headers on all `.dart` files. Exits non-zero if any file is missing a header. |
| `license_add`    | `addlicense` via `addlicense_config.txt`                                                                   | Adds missing Apache 2.0 headers in-place.                                                         |
| `format`         | `dart format lib/ test/ bin/`                                                                              | Reformats source files.                                                                           |
| `format_check`   | `dart format --output=none --set-exit-if-changed …`                                                        | Verifies formatting without modifying files.                                                      |
| `analyze`        | `dart analyze`                                                                                             | Runs the Dart static analyser.                                                                    |
| `test`           | `dart test`                                                                                                | Runs all native platform tests.                                                                   |
| `web_test`       | `dart test --platform chrome test/browser_tokenizer_test.dart`                                             | Runs the browser tokenizer test suite in Chrome.                                                  |
| `coverage`       | `dart test --coverage-path=coverage/lcov.info && genhtml …`                                                | Collects line coverage and renders HTML into `site/coverage/`.                                    |
| `doc`            | `dart doc -o site/api/index.html`                                                                          | Generates API documentation.                                                                      |
| `site`           | Runs `styles`, `site/index.html`, `site/spec.html`, `site/roadmap.html`, `site/api/index.html`, `coverage` | Builds the full documentation site under `site/`.                                                 |
| `android_test`   | `flutter test integration_test/…` on emulator                                                              | Integration tests on Android.                                                                     |
| `ios_test`       | `flutter test integration_test/…` on simulator                                                             | Integration tests on iOS.                                                                         |
| `container_test` | `podman build … && podman run …`                                                                           | Linux CI replica via container.                                                                   |

## Environment variables

| Variable               | Default                                | Purpose                                             |
| ---------------------- | -------------------------------------- | --------------------------------------------------- |
| `ADB_BINARY_PATH`      | `~/Library/Android/sdk/platform-tools` | Path to `adb`.                                      |
| `EMULATOR_ANDROID`     | `android-emulator`                     | Flutter emulator name for Android tests.            |
| `EMULATOR_IOS`         | `ios-emulator`                         | `xcrun simctl` simulator name for iOS tests.        |
| `EMULATOR_IOS_DEVICE`  | `iPhone 17`                            | Device type passed to `emulator_ios_create`.        |
| `EMULATOR_IOS_RUNTIME` | `iOS26.5`                              | Runtime identifier passed to `emulator_ios_create`. |

## License header enforcement

All `.dart` files must carry an Apache 2.0 SPDX comment block. The `addlicense`
tool enforces this. The configuration in `addlicense_config.txt` excludes
generated files, YAML/XML/shell scripts, HTML templates, vendor directories, and
the iOS/Android platform scaffolding inside `integration_test_app/`. The
`license_check` target is the first gate in the `default` pipeline and in CI, so
a file with a missing header blocks the entire build.

# CI/CD

The GitHub Actions workflow (`.github/workflows/cicd.yml`) defines four jobs:

| Job            | Runner           | Targets                                                            |
| -------------- | ---------------- | ------------------------------------------------------------------ |
| `build`        | `ubuntu-latest`  | `make cicd` — full pipeline including coverage and docs            |
| `test-web`     | `ubuntu-latest`  | `make web_test` — browser tokenizer in Chrome (depends on `build`) |
| `test-windows` | `windows-latest` | `make cicd_windows` — `dart pub get && dart test`                  |
| `test-macos`   | `macos-latest`   | `make cicd_macos` — `dart pub get && dart test`                    |

The Linux job installs `libicu-dev` (which provides `libicuuc.so.NN`) and `lcov`
(required for `genhtml`). The macOS job relies on `libicucore.dylib` present in
the OS. The Windows job relies on `icu.dll` shipped with Windows 10+.

The `test-web` and platform jobs both depend on `build` succeeding, ensuring
that formatting, analysis, and the Linux tests pass before the other runners are
launched.

## Linux container

The `Containerfile` defines a two-stage container image:

1. **`addlicense-builder`** — builds `addlicense` from source using the Go
   toolchain (`CGO_ENABLED=0` for a static binary).
2. **`dart:stable`** — installs `make`, `lcov`, `libicu-dev`, and `chromium`;
   copies the `addlicense` binary from stage 1; runs `make cicd` as the default
   command under a non-root `runner` user.

This image replicates the CI environment locally and can be used to diagnose
Linux-specific ICU symbol-suffix issues or coverage regressions:

```sh
make container_test
```

# Test structure

## Native unit tests (`test/`)

| File                               | Tokenizer under test              | Key coverage                                                    |
| ---------------------------------- | --------------------------------- | --------------------------------------------------------------- |
| `test/icu_tokeniser_test.dart`     | `IcuTokenizer`, `RegExpTokenizer` | Tokenizer contract, UAX #29 specifics, platform library loading |
| `test/regexp_tokeniser_test.dart`  | `RegExpTokenizer`                 | Contract, edge cases, technical identifiers                     |
| `test/browser_tokenizer_test.dart` | `BrowserTokenizer`                | Contract, UAX #29, locale constructors (browser platform only)  |

### Tokenizer contract

`_tokenizerContractTests(String label, Tokenizer t)` is a shared test helper
that runs the same invariants against any `Tokenizer` implementation:

- empty string returns `[]`;
- whitespace-only string returns `[]`;
- single word is returned verbatim;
- trailing punctuation is stripped;
- a prose sentence produces only word tokens, no punctuation entries;
- multiple spaces between words are collapsed;
- numbers are included as tokens.

This function is called with both `IcuTokenizer()` and
`const RegExpTokenizer()`, ensuring the two native implementations satisfy an
identical behavioural contract and can be substituted transparently.

### UAX #29 specifics

An additional group, run for `IcuTokenizer` only, verifies behaviours that
require a full Unicode Text Segmentation implementation:

- CJK ideographs are returned as individual tokens (`日本語のテスト` produces
  non-empty output).
- Arabic text produces word tokens (`مرحبا بالعالم`).
- Text containing combining diacritics tokenises correctly (`café latte` →
  `['café', 'latte']`).
- Emoji-only input returns no tokens (`🎉🚀💡` → `[]`).
- Mixed emoji and words: word tokens are retained, emoji spans are discarded.
- Punctuation-only input returns no tokens.
- Hex literals and mixed-case identifiers are kept intact (`0x8004210B`,
  `mTLS`).

The same group of tests is replicated in `test/browser_tokenizer_test.dart` for
`BrowserTokenizer`, verifying that `Intl.Segmenter` delivers equivalent results
in the browser engine.

### Platform library loading

`IcuTokenizer.forPlatform(String platform)` accepts a platform string and
invokes the corresponding branch of `_openIcuLibrary`. This constructor exists
solely to allow the library-loading code paths to be exercised on any host
machine:

| Test scenario                                      | Expected outcome                                        | Skipped on                                          |
| -------------------------------------------------- | ------------------------------------------------------- | --------------------------------------------------- |
| `forPlatform('linux')` on non-Linux                | `UnsupportedError` — all `libicuuc.so.NN` variants fail | Linux (covered by default constructor)              |
| `forPlatform('windows')` on non-Windows            | `UnsupportedError` — no `icu.dll` or `icuuc.dll`        | Windows                                             |
| `forPlatform('android')` on non-Android, non-Linux | Any error — `libicuuc.so` is absent                     | Android; Linux (libicuuc.so present via libicu-dev) |
| `forPlatform('macos')` on non-Apple                | Any error — `libicucore.dylib` is absent                | macOS and iOS                                       |
| `forPlatform('ios')` on macOS                      | Succeeds — `libicucore.dylib` is the same library       | non-macOS                                           |
| `forPlatform('fuchsia')`                           | `UnsupportedError` — no branch for Fuchsia              | —                                                   |

The cross-skip logic ensures that every branch is exercised on every CI runner
without a branch being exercised on the platform where it is the default (and
already covered by `IcuTokenizer()`).

## Browser tests (`test/browser_tokenizer_test.dart`)

The file carries `@TestOn('browser')` at the library level, which prevents the
test runner from including it in the native test suite. The Makefile runs it
separately:

```sh
dart test --platform chrome test/browser_tokenizer_test.dart
```

`dart test` launches a Chromium instance, compiles the test to JavaScript, and
runs it in a headless browser. No WebDriver server is required.

## Mobile integration tests (`integration_test_app/`)

The `integration_test_app/` directory is a minimal Flutter application whose
sole purpose is to run the `IcuTokenizer` test suite on a real Android or iOS
runtime:

- Android: `libicuuc.so` is provided by the NDK; the `.so` is part of the device
  image and requires no packaging steps.
- iOS: `libicucore.dylib` ships with the OS; no additional configuration is
  needed in `Runner.xcodeproj`.

The integration test file mirrors the contract and UAX #29 tests from the native
test suite. Running the tests on device confirms that the FFI bindings work
against the runtime ICU version and that the symbol-suffix probe resolves
correctly.

```sh
# Android
make emulator_android_create   # one-time setup
make android_test

# iOS
make emulator_ios_create       # one-time setup
make ios_test
```

# Memory management

Each call to `IcuTokenizer.tokenise` allocates native memory for the UTF-16 text
buffer and the ICU error-code cell using `calloc` from `package:ffi`. Both
allocations are freed unconditionally in a nested `finally` block:

```
try {
  // allocate textBuf and statusBuf
  try {
    // open iterator, iterate
  } finally {
    ubrk_close(bi);
  }
} finally {
  calloc.free(textBuf);
  calloc.free(statusBuf);
}
```

The outer `finally` runs even if `ubrk_open` throws, so there is no allocation
leak on failure. The iterator is closed in the inner `finally` before the outer
`finally` frees the buffer it points into.

The maximum native allocation per call is `(text.codeUnits.length * 2) + 4`
bytes. For typical document chunks this is a few kilobytes. There is no pooling
or reuse of native buffers between calls; the allocator is expected to handle
this efficiently.

# Error handling

| Condition                                 | Thrown type        | Message                                                      |
| ----------------------------------------- | ------------------ | ------------------------------------------------------------ |
| No ICU library found on Linux             | `UnsupportedError` | Includes the package name to install (`libicu-dev` / `icu`). |
| No ICU DLL found on Windows               | `UnsupportedError` | Generic Windows message.                                     |
| Platform not supported (e.g. Fuchsia)     | `UnsupportedError` | Names the platform.                                          |
| No `ubrk_open[_NN]` symbol in the library | `UnsupportedError` | Describes the renaming issue.                                |
| ICU `UErrorCode > 0` from `ubrk_open`     | `StateError`       | Includes the function name and numeric error code.           |
| `IcuTokenizer()` called on web            | `UnsupportedError` | Directs user to `BrowserTokenizer`.                          |
| `BrowserTokenizer()` called on native     | `UnsupportedError` | Directs user to `IcuTokenizer` or `RegExpTokenizer`.         |

ICU warning codes (`UErrorCode < 0`, e.g. `U_USING_DEFAULT_WARNING = -127`) are
non-fatal and are silently ignored by `_checkStatus`.

# Command-line tool

`bin/tokenize.dart` is a lightweight CLI that exercises both native tokenizers:

```sh
dart run bin/tokenize.dart [--icu | --regexp] <text...>
```

With no flag, both tokenizers are run and their output is printed side by side.
With `--icu` or `--regexp`, only the selected tokenizer runs. The flags are
mutually exclusive; passing both prints a usage error and exits with code 1.
Providing no text also exits with code 1.

# Dependencies

| Package         | Type    | Purpose                                                                                            |
| --------------- | ------- | -------------------------------------------------------------------------------------------------- |
| `ffi: ^2.2.0`   | Runtime | Provides `calloc`, `Pointer`, `Utf8`, and related types for the ICU FFI bindings. Not used on web. |
| `lints: ^6.0.0` | Dev     | Dart recommended lint rules, enforced by `dart analyze`.                                           |
| `test: ^1.25.6` | Dev     | Test runner for all unit and browser tests.                                                        |

The `ffi` package is the only runtime dependency. On web targets, the Dart
compiler tree-shakes the `dart:ffi`-using code because it is gated behind the
conditional export; the `ffi` package itself contributes no web code and adds no
bundle weight.
