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

/// A tokenised word span together with its character offsets in the
/// original text.
///
/// [start] is inclusive and [end] is exclusive, both measured in UTF-16 code
/// units — i.e. Dart `String` index space, matching [String.substring] (so
/// `text.substring(span.start, span.end) == span.text` always holds).
final class TokenSpan {
  /// Creates a [TokenSpan].
  const TokenSpan(this.text, this.start, this.end);

  /// The token's text — identical to what [Tokenizer.tokenise] would have
  /// returned for this span.
  final String text;

  /// The inclusive start offset of this token in the source text.
  final int start;

  /// The exclusive end offset of this token in the source text.
  final int end;

  @override
  String toString() => 'TokenSpan($text, $start, $end)';

  @override
  bool operator ==(Object other) =>
      other is TokenSpan &&
      other.text == text &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(text, start, end);
}

/// A [Tokenizer] that can also report each token's position in the source
/// text.
///
/// Implemented by [IcuTokenizer] and [RegExpTokenizer] — position data is a
/// natural byproduct of both algorithms' underlying implementation (ICU's
/// break iterator and [RegExp] matches both already carry span boundaries).
/// Not implemented by [BrowserTokenizer]: `Intl.Segmenter`'s JS result does
/// carry a comparable `index` field, but no consumer needs offsets from the
/// web tokenizer today — left as a documented future extension rather than
/// implemented speculatively.
abstract interface class OffsetTokenizer implements Tokenizer {
  /// Segments [text] into word tokens with their character offsets.
  ///
  /// Equivalent to [tokenise] but additionally reporting each token's
  /// `(start, end)` span. An empty [text] must return an empty list without
  /// error.
  List<TokenSpan> tokeniseSpans(String text);
}
