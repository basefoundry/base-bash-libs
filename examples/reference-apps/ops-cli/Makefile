.PHONY: test lint fmt

test:
	./tests/run.sh

lint:
	shellcheck --severity=warning bin/app lib/app.sh tests/app.bats

fmt:
	shfmt -w bin/app lib/app.sh tests/app.bats
