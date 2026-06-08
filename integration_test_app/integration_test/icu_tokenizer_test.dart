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
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late IcuTokenizer icu;

  setUpAll(() => icu = IcuTokenizer());

  // -------------------------------------------------------------------------
  // Tokenizer contract — same invariants as the host-side test suite
  // -------------------------------------------------------------------------

  group('IcuTokenizer — Tokenizer contract', () {
    test('empty string returns empty list', () {
      expect(icu.tokenise(''), isEmpty);
    });

    test('whitespace-only string returns empty list', () {
      expect(icu.tokenise('   \t\n  '), isEmpty);
    });

    test('single word', () {
      expect(icu.tokenise('Jekyll'), equals(['Jekyll']));
    });

    test('strips trailing punctuation', () {
      final tokens = icu.tokenise('Hyde,');
      expect(tokens, isNotEmpty);
      expect(tokens.first, isNot(endsWith(',')));
    });

    test('prose sentence returns only word tokens', () {
      const sentence =
          '"The Strange Case of Dr. Jekyll and Mr. Hyde" by Robert Louis Stevenson.';
      final tokens = icu.tokenise(sentence);
      expect(tokens, containsAll(['The', 'Strange', 'Case', 'Jekyll', 'Hyde']));
      expect(tokens, everyElement(isNot(equals('"'))));
      expect(tokens, everyElement(isNot(equals('.'))));
    });

    test('multiple spaces between words', () {
      expect(icu.tokenise('Jekyll   Hyde'), equals(['Jekyll', 'Hyde']));
    });

    test('numbers are included', () {
      expect(icu.tokenise('published in 1886'), contains('1886'));
    });
  });

  // -------------------------------------------------------------------------
  // UAX #29 specifics — verifies ICU WORD rules on the Android runtime
  // -------------------------------------------------------------------------

  group('IcuTokenizer — UAX #29 specifics', () {
    test('keeps hex literal as a single token', () {
      expect(icu.tokenise('error 0x8004210B'), contains('0x8004210B'));
    });

    test('keeps mTLS as a single token', () {
      expect(icu.tokenise('mTLS handshake'), contains('mTLS'));
    });

    test('punctuation and whitespace are not returned as tokens', () {
      for (final t in icu.tokenise('Hello, world! How are you?')) {
        expect(t.trim(), isNotEmpty);
        expect(t, isNot(contains(',')));
        expect(t, isNot(contains('!')));
        expect(t, isNot(contains('?')));
      }
    });

    test('numeric token is returned', () {
      expect(icu.tokenise('published in 1886.'), contains('1886'));
    });

    test('CJK characters are returned as tokens', () {
      expect(icu.tokenise('日本語のテスト'), isNotEmpty);
    });

    test('Arabic text produces word tokens', () {
      final tokens = icu.tokenise('مرحبا بالعالم');
      expect(tokens, isNotEmpty);
      expect(tokens, everyElement((t) => (t as String).trim().isNotEmpty));
    });

    test('text with combining diacritics tokenises correctly', () {
      // "café" — 'e' + combining acute accent U+0301
      expect(icu.tokenise('café latte'), contains('café'));
    });

    test('emoji-only input returns no word tokens', () {
      expect(icu.tokenise('🎉🚀💡'), isEmpty);
    });

    test('mixed emoji and words keeps word tokens', () {
      expect(icu.tokenise('hello 🎉 world'), containsAll(['hello', 'world']));
    });

    test('punctuation-only input returns no tokens', () {
      expect(icu.tokenise('!@#\$%^&*()'), isEmpty);
    });

    test('long text tokenises without error', () {
      final longText = 'The quick brown fox jumps over the lazy dog. ' * 200;
      expect(icu.tokenise(longText).length, greaterThan(100));
    });

    test('leading and trailing whitespace does not produce empty tokens', () {
      final tokens = icu.tokenise('   hello world   ');
      expect(tokens, equals(['hello', 'world']));
      expect(tokens, everyElement(isNot(isEmpty)));
    });
  });
}
