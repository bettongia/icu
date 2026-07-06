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

import 'package:betto_icu/betto_icu.dart';
import 'package:test/test.dart';

void main() {
  // Run the shared OffsetTokenizer contract tests against both
  // implementations that provide it.
  _offsetContractTests('IcuTokenizer', IcuTokenizer());
  _offsetContractTests('RegExpTokenizer', const RegExpTokenizer());

  group('TokenSpan', () {
    test('equality and hashCode are value-based', () {
      const a = TokenSpan('hello', 0, 5);
      const b = TokenSpan('hello', 0, 5);
      const c = TokenSpan('hello', 1, 5);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });

    test('toString includes text and offsets', () {
      const span = TokenSpan('hello', 0, 5);
      expect(span.toString(), contains('hello'));
      expect(span.toString(), contains('0'));
      expect(span.toString(), contains('5'));
    });
  });

  group('IcuTokenizer.tokeniseSpans — trimmed-punctuation offsets', () {
    late IcuTokenizer icu;
    setUpAll(() => icu = IcuTokenizer());

    test(
      'trailing comma grouped into the ICU span is excluded from offsets',
      () {
        // ICU's break iterator groups "Hyde," into a single raw span; the
        // trim-adjustment must shrink the reported end offset so it excludes
        // the comma, not just the returned text.
        const text = 'Hyde, said the doctor';
        final spans = icu.tokeniseSpans(text);
        final hyde = spans.firstWhere((s) => s.text == 'Hyde');
        expect(text.substring(hyde.start, hyde.end), equals('Hyde'));
        expect(hyde.end, lessThan(text.indexOf(',') + 1));
      },
    );

    test(
      'leading punctuation grouped into the ICU span is excluded from offsets',
      () {
        const text = '"Hello" said the doctor';
        final spans = icu.tokeniseSpans(text);
        final hello = spans.firstWhere((s) => s.text == 'Hello');
        expect(text.substring(hello.start, hello.end), equals('Hello'));
        expect(hello.start, greaterThan(0));
      },
    );

    test('every span exactly round-trips via substring', () {
      const text =
          '"The Strange Case of Dr. Jekyll and Mr. Hyde" by R. L. Stevenson.';
      for (final span in icu.tokeniseSpans(text)) {
        expect(text.substring(span.start, span.end), equals(span.text));
      }
    });
  });

  group('IcuTokenizer.tokeniseSpans — multi-byte / surrogate-pair offsets', () {
    late IcuTokenizer icu;
    setUpAll(() => icu = IcuTokenizer());

    test('CJK text: offsets round-trip via substring', () {
      const text = '日本語のテスト';
      final spans = icu.tokeniseSpans(text);
      expect(spans, isNotEmpty);
      for (final span in spans) {
        expect(text.substring(span.start, span.end), equals(span.text));
      }
    });

    test(
      'astral-plane characters (surrogate pairs) do not corrupt offsets',
      () {
        // U+1F600 GRINNING FACE is a surrogate pair (2 UTF-16 code units);
        // offsets are UTF-16-code-unit-based, matching String.substring.
        const text = 'hello 😀 world';
        final spans = icu.tokeniseSpans(text);
        expect(spans.map((s) => s.text), equals(['hello', 'world']));
        for (final span in spans) {
          expect(text.substring(span.start, span.end), equals(span.text));
        }
      },
    );

    test('combining diacritics: offsets round-trip via substring', () {
      const text = 'café latte';
      final spans = icu.tokeniseSpans(text);
      for (final span in spans) {
        expect(text.substring(span.start, span.end), equals(span.text));
      }
      expect(spans.map((s) => s.text), contains('café'));
    });
  });

  group('RegExpTokenizer.tokeniseSpans', () {
    const tokenizer = RegExpTokenizer();

    test('offsets match Match.start/.end exactly', () {
      const text = 'Hello, world!';
      final spans = tokenizer.tokeniseSpans(text);
      expect(spans.map((s) => s.text), equals(['Hello', 'world']));
      for (final span in spans) {
        expect(text.substring(span.start, span.end), equals(span.text));
      }
    });

    test('empty string returns empty list', () {
      expect(tokenizer.tokeniseSpans(''), isEmpty);
    });
  });
}

// Note on BrowserTokenizer: it deliberately does *not* implement
// OffsetTokenizer (see the design note on OffsetTokenizer's doc comment).
// This can't be exercised as a runtime test here — on native test hosts
// (where this suite runs), BrowserTokenizer's constructor throws
// UnsupportedError immediately (it requires dart:js_interop), so there is no
// way to construct an instance to assert against. The exclusion is enforced
// entirely by the type system: BrowserTokenizer implements Tokenizer only,
// so betto_icu.dart exports it without the OffsetTokenizer capability, and
// any attempt to call tokeniseSpans on it fails to compile at the call site.

/// Shared contract tests run against both [OffsetTokenizer] implementations.
void _offsetContractTests(String label, OffsetTokenizer t) {
  group('$label — OffsetTokenizer contract', () {
    test('empty string returns empty list', () {
      expect(t.tokeniseSpans(''), isEmpty);
    });

    test('every returned span\'s text matches text.substring(start, end)', () {
      const text = 'Jekyll and Hyde, published 1886.';
      for (final span in t.tokeniseSpans(text)) {
        expect(text.substring(span.start, span.end), equals(span.text));
      }
    });

    test('tokeniseSpans texts match tokenise() exactly', () {
      const text = '"The Strange Case" by R. L. Stevenson, 1886.';
      expect(
        t.tokeniseSpans(text).map((s) => s.text).toList(),
        equals(t.tokenise(text)),
      );
    });

    test('spans are non-overlapping and in ascending order', () {
      const text = 'one two three four five';
      final spans = t.tokeniseSpans(text);
      for (var i = 1; i < spans.length; i++) {
        expect(spans[i].start, greaterThanOrEqualTo(spans[i - 1].end));
      }
    });

    test('implements Tokenizer and OffsetTokenizer', () {
      expect(t, isA<Tokenizer>());
      expect(t, isA<OffsetTokenizer>());
    });
  });
}
