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

@TestOn('browser')
library;

import 'package:betto_icu/betto_icu.dart';
import 'package:test/test.dart';

void main() {
  late BrowserTokenizer browser;

  setUpAll(() => browser = BrowserTokenizer());

  // -------------------------------------------------------------------------
  // Tokenizer contract
  // -------------------------------------------------------------------------

  group('BrowserTokenizer — Tokenizer contract', () {
    test('empty string returns empty list', () {
      expect(browser.tokenise(''), isEmpty);
    });

    test('whitespace-only string returns empty list', () {
      expect(browser.tokenise('   \t\n  '), isEmpty);
    });

    test('single word', () {
      expect(browser.tokenise('Jekyll'), equals(['Jekyll']));
    });

    test('strips trailing punctuation', () {
      final tokens = browser.tokenise('Hyde,');
      expect(tokens, isNotEmpty);
      expect(tokens.first, isNot(endsWith(',')));
    });

    test('prose sentence returns only word tokens', () {
      const sentence =
          '"The Strange Case of Dr. Jekyll and Mr. Hyde" by Robert Louis Stevenson.';
      final tokens = browser.tokenise(sentence);
      expect(tokens, containsAll(['The', 'Strange', 'Case', 'Jekyll', 'Hyde']));
      expect(tokens, everyElement(isNot(equals('"'))));
      expect(tokens, everyElement(isNot(equals('.'))));
    });

    test('multiple spaces between words', () {
      expect(browser.tokenise('Jekyll   Hyde'), equals(['Jekyll', 'Hyde']));
    });

    test('numbers are included', () {
      expect(browser.tokenise('published in 1886'), contains('1886'));
    });
  });

  // -------------------------------------------------------------------------
  // UAX #29 specifics — verifies Intl.Segmenter behaviour in the browser
  // -------------------------------------------------------------------------

  group('BrowserTokenizer — UAX #29 specifics', () {
    test('keeps mTLS as a single token', () {
      expect(browser.tokenise('mTLS handshake'), contains('mTLS'));
    });

    test('punctuation and whitespace are not returned as tokens', () {
      for (final t in browser.tokenise('Hello, world! How are you?')) {
        expect(t.trim(), isNotEmpty);
        expect(t, isNot(contains(',')));
        expect(t, isNot(contains('!')));
        expect(t, isNot(contains('?')));
      }
    });

    test('numeric token is returned', () {
      expect(browser.tokenise('published in 1886.'), contains('1886'));
    });

    test('CJK characters are returned as tokens', () {
      expect(browser.tokenise('日本語のテスト'), isNotEmpty);
    });

    test('Arabic text produces word tokens', () {
      final tokens = browser.tokenise('مرحبا بالعالم');
      expect(tokens, isNotEmpty);
      expect(tokens, everyElement((t) => (t as String).trim().isNotEmpty));
    });

    test('text with combining diacritics tokenises correctly', () {
      // "café" — 'e' + combining acute accent U+0301
      expect(browser.tokenise('café latte'), contains('café'));
    });

    test('emoji-only input returns no word tokens', () {
      expect(browser.tokenise('🎉🚀💡'), isEmpty);
    });

    test('mixed emoji and words keeps word tokens', () {
      expect(
        browser.tokenise('hello 🎉 world'),
        containsAll(['hello', 'world']),
      );
    });

    test('punctuation-only input returns no tokens', () {
      expect(browser.tokenise('!@#\$%^&*()'), isEmpty);
    });

    test('long text tokenises without error', () {
      final longText = 'The quick brown fox jumps over the lazy dog. ' * 200;
      expect(browser.tokenise(longText).length, greaterThan(100));
    });

    test('leading and trailing whitespace does not produce empty tokens', () {
      final tokens = browser.tokenise('   hello world   ');
      expect(tokens, equals(['hello', 'world']));
      expect(tokens, everyElement(isNot(isEmpty)));
    });
  });

  // -------------------------------------------------------------------------
  // Tokenizer interface
  // -------------------------------------------------------------------------

  group('BrowserTokenizer — Tokenizer interface', () {
    test('is assignable to Tokenizer', () {
      final Tokenizer t = BrowserTokenizer();
      expect(t.tokenise('hello world'), equals(['hello', 'world']));
    });

    test('default locale constructor works', () {
      expect(BrowserTokenizer().tokenise('hello'), equals(['hello']));
    });

    test('explicit locale constructor works', () {
      expect(BrowserTokenizer('en').tokenise('hello'), equals(['hello']));
    });
  });
}
