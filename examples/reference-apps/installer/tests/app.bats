#!/usr/bin/env bats

setup() {
    project_root="$(cd -- "${BATS_TEST_DIRNAME}/.." && pwd -P)"
    launcher="${BASE_BASH_LAUNCHER:-$project_root/../../../bin/base-bash}"
    export BASE_BASH_LIBS_DIR="${BASE_BASH_LIBS_DIR:-$project_root/../../../lib/bash}"
    export BASE_REFERENCE_INSTALL_TARGET="$BATS_TEST_TMPDIR/install"
}

run_app() { "$launcher" "$project_root/bin/app" "$@"; }

@test "installer reports status and supports a dry-run" {
    run run_app status
    [ "$status" -eq 0 ]
    [[ "$output" == *"state=absent"* ]]
    run run_app install --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"dry-run=install"* ]]
}

@test "installer writes an idempotent state marker" {
    run run_app install
    [ "$status" -eq 0 ]
    [ -f "$BASE_REFERENCE_INSTALL_TARGET/state.txt" ]
    run run_app update
    [ "$status" -eq 0 ]
    grep -F 'operation=update' "$BASE_REFERENCE_INSTALL_TARGET/state.txt"
}

@test "installer rejects unknown commands with a usage status" {
    run run_app missing
    [ "$status" -eq 2 ]
}
