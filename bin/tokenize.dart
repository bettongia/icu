// Copyright 2026 The Authors.
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

import 'dart:io';

import 'package:betto_icu/betto_icu.dart';

void printUsage() {
  print('Usage: tokenize [--icu | --regexp] <text>');
  print('');
  print('Options:');
  print('  --icu     Use only the IcuTokenizer (UAX #29, system ICU)');
  print('  --regexp  Use only the RegExpTokenizer (pure Dart, Latin)');
  print('  --help    Show this help message');
  print('');
  print('Default: run both tokenizers and show each result.');
}

void main(List<String> args) {
  var useIcu = false;
  var useRegExp = false;
  final textParts = <String>[];

  for (final arg in args) {
    switch (arg) {
      case '--icu':
        useIcu = true;
      case '--regexp':
        useRegExp = true;
      case '--help' || '-h':
        printUsage();
        exit(0);
      case _:
        textParts.add(arg);
    }
  }

  if (useIcu && useRegExp) {
    stderr.writeln('Error: --icu and --regexp are mutually exclusive.');
    printUsage();
    exit(1);
  }

  if (textParts.isEmpty) {
    stderr.writeln('Error: no text provided.');
    printUsage();
    exit(1);
  }

  final text = textParts.join(' ');
  final showBoth = !useIcu && !useRegExp;

  if (useIcu || showBoth) {
    print('IcuTokenizer:    ${IcuTokenizer().tokenise(text)}');
  }
  if (useRegExp || showBoth) {
    print('RegExpTokenizer: ${RegExpTokenizer().tokenise(text)}');
  }
}
