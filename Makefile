.DEFAULT_GOAL := default

# BEGIN: Primary tasks

default: clean prepare license_check format analyze test coverage doc
.PHONY: default

cicd: default
.PHONY: cicd

example:
	dart run example/betto_icu_example.dart
.PHONY: example

# END: Primary tasks

format:
	dart format .
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
