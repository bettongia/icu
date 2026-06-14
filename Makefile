.DEFAULT_GOAL := default

export ADB_BINARY_PATH ?= ~/Library/Android/sdk/platform-tools
export EMULATOR_ANDROID ?= android-emulator
export EMULATOR_IOS ?= ios-emulator
export EMULATOR_IOS_DEVICE ?= iPhone\ 17
export EMULATOR_IOS_RUNTIME ?= iOS26.5

# BEGIN: Primary tasks

default: clean prepare license_check format analyze test coverage site
.PHONY: default

cicd: default
.PHONY: cicd

pre_commit: format_check analyze license_check test
.PHONY: pre_commit

cicd_windows: prepare test
.PHONY: cicd_windows

cicd_macos: prepare test
.PHONY: cicd_macos

example:
	dart run example/betto_icu_example.dart
.PHONY: example

# Run integration tests on a connected Android emulator or device.
# Requires Flutter and an emulator reachable via `flutter devices`.
# Usage: make android_test [DEVICE=<device-id>]
android_test:
	cd integration_test_app && \
	  flutter pub get && \
	  flutter emulators --launch $(EMULATOR_ANDROID) ||true && \
	  $(ADB_BINARY_PATH)/adb wait-for-device && \
	  flutter test integration_test/icu_tokenizer_test.dart --device-id emulator-5554
.PHONY: android_test

# Run integration tests on a connected iOS simulator or device.
# Requires Xcode and a simulator reachable via `flutter devices`.
# Usage: make ios_test [DEVICE=<device-id>]
ios_test:
	cd integration_test_app && \
	  flutter pub get && \
	  xcrun simctl list | grep "$(EMULATOR_IOS)" | grep -q "Booted" || xcrun simctl boot $(EMULATOR_IOS) && \
	  open -a Simulator && \
	  flutter test integration_test/icu_tokenizer_test.dart --device-id $(EMULATOR_IOS)
.PHONY: ios_test

# Run BrowserTokenizer tests in Chrome. Requires Chrome to be installed.
# Usage: make web_test
web_test: prepare
	dart test --platform chrome test/browser_tokenizer_test.dart
.PHONY: web_test

# END: Primary tasks

# START: Mobile emulators

emulators_stop: emulators_stop_android emulators_stop_ios

emulators_stop_android:
	$(ADB_BINARY_PATH)/adb -e emu kill || true

emulators_stop_ios:
	xcrun simctl shutdown $(EMULATOR_IOS) || true

.PHONY: emulators_stop emulators_stop_android emulators_stop_ios

emulator_android_create:
	flutter emulators --create --name $(EMULATOR_ANDROID)
.PHONY: emulator_android_create

emulator_ios_create:
	xcrun simctl create $(EMULATOR_IOS) $(EMULATOR_IOS_DEVICE) $(EMULATOR_IOS_RUNTIME)
.PHONY: emulator_ios_create

# END: Mobile emulators

# START: Container tests
container_test:
	podman build -t betto-icu-cicd .
	podman run --rm betto-icu-cicd
	podman run --rm betto-icu-cicd make web_test

# END: Container tests

format:
	dart format lib/ test/ bin/
.PHONY: format

format_check:
	dart format --output=none --set-exit-if-changed lib/ test/ hook/ tool/
.PHONY: format_check

analyze:
	dart analyze
.PHONY: analyze

test:
	dart test
.PHONY: test


license_check:
	cat addlicense_config.txt | xargs addlicense --check

license_add:
	cat addlicense_config.txt | xargs addlicense
.PHONY: license_add license_check


coverage: coverage.log
.PHONY: coverage

coverage.log: lib/** test/**
	# flutter test --coverage
	dart test --coverage-path=coverage/lcov.info
	rm -rf site/coverage
	mkdir -p site/coverage
	genhtml coverage/lcov.info -o site/coverage

# BEGIN: Documentation site tasks
site/:
	mkdir -p site

site: styles site/index.html site/spec.html site/roadmap.html site/api/index.html coverage | site/
.PHONY: site

styles: site/styles/styles.css
.PHONY: styles

site/index.html:  docs/index.md docs/.pandoc docs/template/header.html | site/
	pandoc --defaults="docs/.pandoc" docs/index.md README.md -o "site/index.html";

site/spec.html:  docs/spec/*.md docs/template/header.html | site/
	pandoc --defaults="docs/spec/.pandoc" --mathml docs/spec/*.md -o "site/spec.html";

site/roadmap.html: docs/roadmap/*.md docs/.pandoc docs/template/header.html | site/
	pandoc --defaults="docs/.pandoc" docs/roadmap/v*.md -o "site/roadmap.html";

site/styles/styles.css: docs/styles/styles.css | site/
	mkdir -p site/styles/
	cp docs/styles/styles.css site/styles/styles.css

site/api/index.html:
	dart doc -o site/api/index.html

# END: Documentation site tasks

prepare:
	dart pub global activate coverage
	dart pub get
.PHONY: prepare

clean:
	rm -rf coverage
	rm -rf doc
.PHONY: clean
