.DEFAULT_GOAL := default

# BEGIN: Primary tasks

default: clean prepare license_check format analyze test coverage doc
.PHONY: default

cicd: default
.PHONY: cicd

cicd-windows: prepare test
.PHONY: cicd-windows

cicd-macos: prepare test
.PHONY: cicd-macos

example:
	dart run example/betto_icu_example.dart
.PHONY: example

# Run integration tests on a connected Android emulator or device.
# Requires Flutter and an emulator reachable via `flutter devices`.
# Usage: make android_test [DEVICE=<device-id>]
android_test:
	cd integration_test_app && \
	  flutter pub get && \
	  flutter test integration_test/icu_tokenizer_test.dart \
	    $(if $(DEVICE),--device-id $(DEVICE),)
.PHONY: android_test

# Run integration tests on a connected iOS simulator or device.
# Requires Xcode and a simulator reachable via `flutter devices`.
# Usage: make ios_test [DEVICE=<device-id>]
ios_test:
	cd integration_test_app && \
	  flutter pub get && \
	  flutter test integration_test/icu_tokenizer_test.dart \
	    $(if $(DEVICE),--device-id $(DEVICE),)
.PHONY: ios_test

# Run BrowserTokenizer tests in Chrome. Requires Chrome to be installed.
# Usage: make web_test
web_test: prepare
	dart test --platform chrome test/browser_tokenizer_test.dart
.PHONY: web_test

# END: Primary tasks

format:
	dart format lib/ test/ bin/
.PHONY: format

analyze:
	dart analyze
.PHONY: analyze

test:
	dart test
.PHONY: test

doc:
	dart doc
.PHONY: doc

license_check:
	cat addlicense_config.txt | xargs addlicense --check

license_add:
	cat addlicense_config.txt | xargs addlicense
.PHONY: license_add license_check

coverage:
	dart test --coverage-path=coverage/lcov.info
	genhtml coverage/lcov.info --output-dir coverage/html
.PHONY: coverage

prepare:
	dart pub global activate coverage
	dart pub get
.PHONY: prepare

clean:
	rm -rf coverage
	rm -rf doc
.PHONY: clean
