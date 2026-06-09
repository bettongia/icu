.DEFAULT_GOAL := default

export ADB_BINARY_PATH ?= ~/Library/Android/sdk/platform-tools
export EMULATOR_ANDROID ?= android-emulator
export EMULATOR_IOS ?= ios-emulator
export EMULATOR_IOS_DEVICE ?= iPhone\ 17
export EMULATOR_IOS_RUNTIME ?= iOS26.5

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
