#!/usr/bin/env bash
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
if ! command -v bats >/dev/null 2>&1; then
    printf 'ERROR: bats is required\n' >&2
    exit 1
fi
bats "$repo_root/tests/app.bats" || exit $?
