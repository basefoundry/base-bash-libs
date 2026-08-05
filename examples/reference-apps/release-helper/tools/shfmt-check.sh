#!/usr/bin/env bash
if ! command -v shfmt >/dev/null 2>&1; then
    printf 'ERROR: shfmt is required\n' >&2
    exit 1
fi
shfmt -d bin/app lib/app.sh tests/app.bats || exit $?
