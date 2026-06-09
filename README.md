# betto_icu

Unicode text tokenization for Dart.

[![CI/CD](https://github.com/bettongia/icu/actions/workflows/cicd.yml/badge.svg)](https://github.com/bettongia/icu/actions/workflows/cicd.yml)
[![Codemagic build status for Android and iOS](https://api.codemagic.io/apps/6a2748d16b80ac5b260f7d52/flutter-integration-tests/status_badge.svg)](https://codemagic.io/app/6a2748d16b80ac5b260f7d52/flutter-integration-tests/latest_build)

Four exports, one import:

| Class              | Description                                                                                                  |
| ------------------ | ------------------------------------------------------------------------------------------------------------ |
| `Tokenizer`        | Abstract segmentation interface                                                                              |
| `IcuTokenizer`     | UAX #29 word boundaries via the system ICU FFI library. Handles non-Latin scripts (CJK, Thai, Arabic, etc.). |
| `RegExpTokenizer`  | Pure-Dart, Latin/English fallback using `RegExp`. Zero FFI dependencies.                                     |
| `BrowserTokenizer` | UAX #29 word boundaries via the browser's `Intl.Segmenter` API. Web only; zero bundle cost.                  |

## Platform support

`IcuTokenizer` links against the system ICU library — no bundling required.

| Platform    | Library                                                           |
| ----------- | ----------------------------------------------------------------- |
| macOS / iOS | `libicucore.dylib` (ships with the OS)                            |
| Android     | `libicuuc.so` (NDK)                                               |
| Linux       | `libicuuc.so.NN` (widely packaged; install `libicu-dev` or `icu`) |
| Windows     | `icu.dll` (Windows 10+)                                           |
| Web         | Browser `Intl.Segmenter` (Chrome 87+, Firefox 125+, Safari 16.4+) |

`RegExpTokenizer` works on every platform including web. `BrowserTokenizer`
works on web only — it uses `dart:js_interop` to call the browser's built-in
`Intl.Segmenter`.

## Getting started

```yaml
dependencies:
  betto_icu: ^0.1.0
```

Requires Dart SDK `^3.12.0`.

## Usage

```dart
import 'package:betto_icu/betto_icu.dart';

void main() {
  // IcuTokenizer — UAX #29, handles any script
  final icu = IcuTokenizer();
  print(icu.tokenise('"The Strange Case of Dr. Jekyll and Mr. Hyde"'));
  // → [The, Strange, Case, of, Dr, Jekyll, and, Mr, Hyde]

  // RegExpTokenizer — pure Dart, English/Latin only
  final re = RegExpTokenizer();
  print(re.tokenise('mTLS handshake in 0x8004'));
  // → [mTLS, handshake, in, 0x8004]

  // Both implement Tokenizer, so they are interchangeable
  final Tokenizer t = IcuTokenizer();
  print(t.tokenise(''));  // → []
}
```

The [`tokenize`](bin/tokenize.dart) command-line tool takes an input string and
returns the token list for each or both tokenizer:

```sh
dart run bin/tokenize.dart "The Strange Case of Dr. Jekyll and Mr. Hyde"
```

### Choosing an implementation

Use `IcuTokenizer` when your text may contain non-Latin scripts (CJK, Thai,
Arabic, Devanagari, etc.) on a native platform — it delegates word-boundary
detection to the OS-provided ICU library and conforms to UAX #29.

Use `BrowserTokenizer` on Flutter Web when your text may contain non-Latin
scripts. It calls `Intl.Segmenter` in the browser's own JavaScript engine, which
is backed by the same ICU data, with no bundle overhead and no FFI. Requires
Chrome 87+, Firefox 125+, or Safari 16.4+.

Use `RegExpTokenizer` when you only process English prose or technical
identifiers and want zero FFI dependencies, or as a fallback on older browsers
that don't support `Intl.Segmenter`.

### ubrk_getRuleStatus note (macOS / iOS)

Apple's `libicucore` does not export UAX #29 rule-status tags in its compiled
word break rules. `IcuTokenizer` uses character-class `RegExp` matching for span
classification rather than `ubrk_getRuleStatus()`, making it portable across all
supported platforms.

## Testing

Run the test suite:

```
make test
```

Collect line coverage (requires the `coverage` pub global tool):

```
make coverage
```

### Test structure

| File                                                            | What it covers                                                         |
| --------------------------------------------------------------- | ---------------------------------------------------------------------- |
| `test/icu_tokeniser_test.dart`                                  | `IcuTokenizer` contract, UAX #29 behaviour, platform library loading   |
| `test/regexp_tokeniser_test.dart`                               | `RegExpTokenizer` contract and edge cases                              |
| `integration_test_app/integration_test/icu_tokenizer_test.dart` | `IcuTokenizer` contract and UAX #29 behaviour on Android / iOS         |
| `test/browser_tokenizer_test.dart`                              | `BrowserTokenizer` contract and UAX #29 behaviour via `Intl.Segmenter` |

**Tokenizer contract** — a shared `_tokenizerContractTests` helper runs the same
invariants (empty input, punctuation stripping, numbers, prose sentences)
against both implementations to ensure they are interchangeable.

**UAX #29 specifics** — tests that verify ICU-only behaviour: CJK ideographs,
Arabic, combining diacritics, emoji filtering, and hex/mixed-case identifiers
such as `mTLS` and `0x8004210B`.

**Platform library loading** — `IcuTokenizer.forPlatform(String platform)` lets
tests drive each OS branch on any host machine. Each test is skipped on its
native platform (where `IcuTokenizer()` already covers those lines) and runs on
all other platforms, so coverage stays above 90% regardless of which CI runner
executes the suite.

| Test                                   | macOS   | Linux   | Windows |
| -------------------------------------- | ------- | ------- | ------- |
| `macos` — expects load error           | skipped | runs    | runs    |
| `ios` — loads `libicucore.dylib`       | runs    | skipped | skipped |
| `linux` — expects `UnsupportedError`   | runs    | skipped | runs    |
| `windows` — expects `UnsupportedError` | runs    | runs    | skipped |
| `android` — expects load error         | runs    | skipped | runs    |
| `fuchsia` — expects `UnsupportedError` | runs    | runs    | runs    |

The `android` test is skipped on Linux because `libicuuc.so` is present there
(installed by `libicu-dev`).

### Android emulator

The `integration_test_app/` directory contains a minimal Flutter app that runs
the full contract and UAX #29 test suite on a real Android runtime via
[`package:integration_test`](https://pub.dev/packages/integration_test).

Prerequisites: Flutter SDK and a running emulator (or connected device).

```sh
make emulator_android_create
make android_test
make emulators_stop_android
```

### iOS simulator

The same `integration_test_app/` runs on an iOS simulator or physical device.
ICU on iOS comes from Apple's `libicucore.dylib`, which ships with the OS and
exports symbols without version renaming.

Prerequisites: Xcode and a booted simulator (or connected device).

```sh
make emulator_ios_create
make ios_test
make emulators_stop_ios
```

### Web browser

`BrowserTokenizer` tests live in the main package and run with `dart test`,
which launches Chrome directly — no WebDriver server required.

```sh
make web_test
```

### Linux container

The [Containerfile](Containerfile) can be used to test the package on Linux.

```sh
make container_test
```

## License

Apache 2.0 — see [LICENSE](LICENSE).
