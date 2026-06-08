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

import 'dart:js_interop';

import 'tokenizer.dart';

// ---------------------------------------------------------------------------
// JS interop bindings
// ---------------------------------------------------------------------------

@JS('Intl.Segmenter')
extension type _IntlSegmenter._(JSObject _) implements JSObject {
  // locales is a JSArray<JSString> — the array form accepted by all Intl APIs.
  // Passing an empty array selects the browser's default locale.
  external factory _IntlSegmenter(
    JSArray<JSString> locales,
    _SegmenterOptions options,
  );
  external _Segments segment(JSString input);
}

@JS()
extension type _SegmenterOptions._(JSObject _) implements JSObject {
  external factory _SegmenterOptions({required JSString granularity});
}

@JS()
extension type _Segments._(JSObject _) implements JSObject {}

@JS()
extension type _SegmentData._(JSObject _) implements JSObject {
  external JSString get segment;
  external JSBoolean get isWordLike;
}

// Converts any JS iterable (including Segments) to a JSArray.
@JS('Array.from')
external JSArray<_SegmentData> _arrayFrom(JSObject iterable);

// ---------------------------------------------------------------------------
// BrowserTokenizer
// ---------------------------------------------------------------------------

/// A [Tokenizer] backed by the browser's built-in [Intl.Segmenter] API.
///
/// Delegates word-boundary detection to the JavaScript engine's own ICU
/// implementation via [Intl.Segmenter] with `granularity: 'word'`. Segments
/// with `isWordLike: true` are returned; spaces and punctuation are dropped.
///
/// This gives UAX #29-quality segmentation with zero bundle cost — the browser
/// ships ICU internally. Chrome 87+, Firefox 125+, and Safari 16.4+ are
/// supported.
///
/// Only available on web targets where `dart:js_interop` is present. On
/// native targets the conditional import resolves to [BrowserTokenizer] from
/// `browser_tokenizer_stub.dart`, which throws [UnsupportedError].
///
/// ## Example
///
/// ```dart
/// final tokenizer = BrowserTokenizer();
/// print(tokenizer.tokenise('Dr. Jekyll and Mr. Hyde'));
/// // → ['Dr', 'Jekyll', 'and', 'Mr', 'Hyde']
/// ```
class BrowserTokenizer implements Tokenizer {
  final _IntlSegmenter _segmenter;

  /// Creates a [BrowserTokenizer] using [locale] for segmentation hints.
  ///
  /// [locale] defaults to `''` (browser default locale), which is appropriate
  /// for multi-language content. Pass a BCP 47 tag (e.g. `'ja'`) to favour a
  /// specific language's word-breaking rules where the engine supports it.
  BrowserTokenizer([String locale = ''])
    : _segmenter = _IntlSegmenter(
        (locale.isEmpty ? <JSString>[] : [locale.toJS]).toJS,
        _SegmenterOptions(granularity: 'word'.toJS),
      );

  @override
  List<String> tokenise(String text) {
    if (text.isEmpty) return const [];
    final segments = _segmenter.segment(text.toJS);
    final array = _arrayFrom(segments);
    final result = <String>[];
    for (var i = 0; i < array.length; i++) {
      final data = array[i];
      if (data.isWordLike.toDart) {
        result.add(data.segment.toDart);
      }
    }
    return result;
  }
}
