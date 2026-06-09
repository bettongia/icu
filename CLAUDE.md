# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```sh
# Full CI pipeline (clean, prepare, license check, format, analyze, test, coverage, doc)
make

# Individual steps
make prepare        # dart pub global activate coverage && dart pub get
make format         # dart format lib/ test/ bin/
make analyze        # dart analyze
make test           # dart test (native platforms only — excludes browser)
make coverage       # dart test --coverage-path=coverage/lcov.info + genhtml
make license_check  # addlicense --check (Apache 2.0 header enforcement)
make license_add    # add missing Apache 2.0 headers
make doc            # dart doc
make example        # dart run example/betto_icu_example.dart

# Run a single test file
dart test test/icu_tokeniser_test.dart

# Run a single test by name
dart test --name "CJK characters are returned as tokens"

# Browser tests (requires Chrome)
make web_test       # dart test --platform chrome test/browser_tokenizer_test.dart

# Mobile integration tests (requires Flutter + emulator/device)
make android_test   # launches EMULATOR_ANDROID, waits for device, runs tests
make ios_test       # boots EMULATOR_IOS simulator, runs tests

# Emulator management
make emulator_android_create   # flutter emulators --create --name $EMULATOR_ANDROID
make emulator_ios_create       # xcrun simctl create $EMULATOR_IOS $EMULATOR_IOS_DEVICE $EMULATOR_IOS_RUNTIME
make emulators_stop            # kills Android emulator and shuts down iOS simulator

# Linux container (replicates CI)
podman build -t betto-icu-cicd . && podman run --rm betto-icu-cicd
```

### Makefile environment variables

| Variable              | Default                              | Purpose                                      |
|-----------------------|--------------------------------------|----------------------------------------------|
| `ADB_BINARY_PATH`     | `~/Library/Android/sdk/platform-tools` | Path to `adb`                              |
| `EMULATOR_ANDROID`    | `android-emulator`                   | Android emulator name for `flutter emulators` |
| `EMULATOR_IOS`        | `ios-emulator`                       | iOS simulator name for `xcrun simctl`        |
| `EMULATOR_IOS_DEVICE` | `iPhone 17`                          | Device type for `emulator_ios_create`        |
| `EMULATOR_IOS_RUNTIME`| `iOS26.5`                            | Runtime for `emulator_ios_create`            |

## Architecture

This is a Dart package (`betto_icu`) that provides a `Tokenizer` interface with three implementations:

- **`RegExpTokenizer`** — pure Dart, Latin/English only, zero dependencies
- **`IcuTokenizer`** — FFI into the OS system ICU library (`libicucore.dylib` / `libicuuc.so` / `icu.dll`), UAX #29 compliant, handles CJK/Arabic/Thai/etc.
- **`BrowserTokenizer`** — calls browser `Intl.Segmenter` via `dart:js_interop`, web-only

### Conditional exports (the key design pattern)

`lib/betto_icu.dart` uses Dart's conditional export syntax to select the right implementation per target:

```dart
export 'src/icu_tokenizer_stub.dart'
    if (dart.library.ffi) 'src/icu_tokenizer.dart'
    show IcuTokenizer;

export 'src/browser_tokenizer_stub.dart'
    if (dart.library.js_interop) 'src/browser_tokenizer.dart'
    show BrowserTokenizer;
```

Each class has a real implementation file and a stub file. The stub throws `UnsupportedError` on construction. This keeps the public API surface identical across all targets while ensuring unavailable APIs fail loudly.

### ICU FFI specifics (`lib/src/icu_tokenizer.dart`)

- `_openIcuLibrary()` tries platform-appropriate library names with fallthrough candidates (e.g. `libicuuc.so.76`, `.74`, `.73` …). On Windows, only `icu.dll` and `icuuc.dll` are tried — Windows does not use version-suffixed DLL names.
- `_icuSymbolSuffix()` probes for `ubrk_open` vs `ubrk_open_76` etc., because Debian Trixie+ and Fedora rename ICU symbols with the major version suffix. Probes versions 76 down to 64 (including 69).
- `ubrk_getRuleStatus()` is **not used** for span classification because Apple's `libicucore` does not export UAX #29 rule-status tags; instead a `\p{L}\p{N}` `RegExp` classifies spans — this is portable across all platforms.
- The FFI bindings are resolved once at construction; each `tokenise()` call allocates a temporary native UTF-16 buffer via `calloc` and frees it in a `finally` block.
- `_checkStatus` is a `static` method — it uses no instance state.

### Test structure

- `_tokenizerContractTests()` in `test/icu_tokeniser_test.dart` is a shared helper that runs invariant tests against **both** `IcuTokenizer` and `RegExpTokenizer` — any new implementation should be added there
- `IcuTokenizer.forPlatform(String platform)` lets tests exercise non-native library-loading paths; `dart test` skips each branch on its native host
- Browser tests live in `test/browser_tokenizer_test.dart` and require `--platform chrome`
- Mobile integration tests live in `integration_test_app/` and require Flutter

### License

All `.dart` files require an Apache 2.0 header. `addlicense` enforces this; `make license_check` will fail CI if headers are missing. Run `make license_add` to add them. Config in `addlicense_config.txt`.
