#!/usr/bin/env bash

# Reusable consumer-facing helpers; this file has no BATS dependency.

consumer_project_root() {
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P
}

consumer_framework_dir() {
    printf '%s\n' "${BASE_BASH_LIBS_DIR:-$(consumer_project_root)/lib/bash}"
}

consumer_setup_tmpdir() {
    local root="${1:-${BATS_TEST_TMPDIR:-${TMPDIR:-/tmp}}}"
    CONSUMER_TMPDIR="$(mktemp -d "$root/base-bash-consumer.XXXXXX")" || return 1
    export CONSUMER_TMPDIR
}

consumer_run() {
    local project_dir="$1"
    shift
    local framework_dir
    framework_dir="$(consumer_framework_dir)"
    PATH="$(consumer_project_root)/bin:$PATH" \
        BASE_BASH_LIBS_DIR="$framework_dir" \
        "$project_dir/bin/app" "$@"
}

consumer_check() {
    local project_dir="$1"
    local format="${2:-human}"
    BASE_BASH_LIBS_DIR="$(consumer_framework_dir)" \
        "$(consumer_project_root)/bin/base-bash" check --project "$project_dir" --format "$format"
}

consumer_assert_status() {
    local expected="$1"
    shift
    local actual
    "$@"
    actual=$?
    [[ "$actual" -eq "$expected" ]]
}
