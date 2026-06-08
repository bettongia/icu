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

import 'tokenizer.dart';

/// Stub [BrowserTokenizer] for native (non-web) targets.
///
/// The real implementation lives in `browser_tokenizer.dart` and is selected
/// via conditional import on targets where `dart:js_interop` is available.
/// On all other targets this stub is used and throws [UnsupportedError] at
/// construction time.
class BrowserTokenizer implements Tokenizer {
  BrowserTokenizer([String locale = '']) {
    throw UnsupportedError(
      'BrowserTokenizer requires a browser environment with '
      'dart:js_interop. Use IcuTokenizer or RegExpTokenizer on native '
      'platforms.',
    );
  }

  @override
  List<String> tokenise(String text) => throw UnsupportedError(
    'BrowserTokenizer is only available on web targets.',
  );
}
