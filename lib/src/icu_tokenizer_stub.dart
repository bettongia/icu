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

/// Stub [IcuTokenizer] for web targets where `dart:ffi` is unavailable.
///
/// The real implementation lives in `icu_tokenizer.dart` and is selected via
/// conditional import on targets where `dart:ffi` is available (native
/// platforms). On web this stub is used and throws [UnsupportedError] at
/// construction time. Use [BrowserTokenizer] on web instead.
class IcuTokenizer implements Tokenizer {
  IcuTokenizer() {
    throw UnsupportedError(
      'IcuTokenizer requires dart:ffi and is not available on web. '
      'Use BrowserTokenizer on web targets.',
    );
  }

  IcuTokenizer.forPlatform(String platform) {
    throw UnsupportedError(
      'IcuTokenizer requires dart:ffi and is not available on web. '
      'Use BrowserTokenizer on web targets.',
    );
  }

  @override
  List<String> tokenise(String text) =>
      throw UnsupportedError('IcuTokenizer is not available on web targets.');
}
