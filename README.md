# betto_icu

Unicode text tokenization for Dart.

Three exports, one import:

| Class             | Description                                                                                                  |
| ----------------- | ------------------------------------------------------------------------------------------------------------ |
| `Tokenizer`       | Abstract segmentation interface                                                                              |
| `IcuTokenizer`    | UAX #29 word boundaries via the system ICU FFI library. Handles non-Latin scripts (CJK, Thai, Arabic, etc.). |
| `RegExpTokenizer` | Pure-Dart, Latin/English fallback using `RegExp`. Zero FFI dependencies.                                     |

## Platform support

`IcuTokenizer` links against the system ICU library — no bundling required.

| Platform    | Library                                                           |
| ----------- | ----------------------------------------------------------------- |
| macOS / iOS | `libicucore.dylib` (ships with the OS)                            |
| Android     | `libicuuc.so` (NDK)                                               |
| Linux       | `libicuuc.so.NN` (widely packaged; install `libicu-dev` or `icu`) |
| Windows     | `icu.dll` (Windows 10+)                                           |

`RegExpTokenizer` works on every platform including web.

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
Arabic, Devanagari, etc.) — it delegates word-boundary detection to the
OS-provided ICU library and conforms to UAX #29.

Use `RegExpTokenizer` when you only process English prose or technical
identifiers and want zero FFI dependencies (e.g. on web targets where `dart:ffi`
is unavailable).

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

| File                              | What it covers                                                       |
| --------------------------------- | -------------------------------------------------------------------- |
| `test/icu_tokeniser_test.dart`    | `IcuTokenizer` contract, UAX #29 behaviour, platform library loading |
| `test/regexp_tokeniser_test.dart` | `RegExpTokenizer` contract and edge cases                            |

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
| `android` — expects load error         | runs    | runs    | runs    |
| `fuchsia` — expects `UnsupportedError` | runs    | runs    | runs    |

## License

Apache 2.0 — see [LICENSE](LICENSE).
