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

/// Abstract interface for text segmentation.
///
/// Implementations segment a string into word-like tokens, discarding
/// whitespace and punctuation boundaries. The pipeline then normalises and
/// stems the returned tokens; this interface is responsible only for the
/// segmentation step.
///
/// ## Implementations
///
/// This package provides two implementations:
///
/// - [RegExpTokenizer] — pure Dart, suitable for English-language prose and
///   common technical identifiers. Zero FFI dependencies.
/// - [IcuTokenizer] — backed by the system ICU library via FFI. Conforms to
///   UAX #29 Unicode Text Segmentation and handles non-Latin scripts (CJK,
///   Thai, Arabic, etc.) correctly. Prefer this implementation for
///   multi-language use cases.
///
/// The interface is intentionally narrow so the implementation can be swapped
/// without touching the calling pipeline.
///
/// ## Unicode Text Segmentation
///
/// Conformant implementations should follow UAX #29 Unicode Text Segmentation
/// rules for word boundaries. [IcuTokenizer] provides a full UAX #29
/// implementation via the system ICU library.
///
/// ## Example
///
/// ```dart
/// final tokenizer = RegExpTokenizer();
/// final tokens = tokenizer.tokenise('Dr. Jekyll and Mr. Hyde');
/// // → ['Dr', 'Jekyll', 'and', 'Mr', 'Hyde']
/// ```
abstract interface class Tokenizer {
  /// Segments [text] into word tokens.
  ///
  /// Returns only word-like spans (letters, numbers, mixed-case identifiers).
  /// Punctuation, whitespace, and other non-word spans are discarded.
  ///
  /// An empty [text] must return an empty list without error.
  List<String> tokenise(String text);
}
