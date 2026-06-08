// Copyright 2026 The Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

/// Unicode text tokenization for Dart.
///
/// Provides three exports:
///
/// - [Tokenizer] — the abstract segmentation interface.
/// - [IcuTokenizer] — UAX #29 word boundaries via the system ICU FFI library.
///   Handles non-Latin scripts (CJK, Thai, Arabic, etc.). Preferred for
///   multi-language use cases.
/// - [RegExpTokenizer] — pure-Dart, Latin/English fallback using [RegExp].
///   Zero FFI dependencies; suitable for English prose and common technical
///   identifiers.
library;

export 'src/tokenizer.dart' show Tokenizer;
export 'src/icu_tokenizer.dart' show IcuTokenizer;
export 'src/regexp_tokenizer.dart' show RegExpTokenizer;
