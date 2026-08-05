#!/usr/bin/env bats

setup() {
    project_root="$(cd -- "${BATS_TEST_DIRNAME}/.." && pwd -P)"
    launcher="${BASE_BASH_LAUNCHER:-$project_root/../../../bin/base-bash}"
    export BASE_BASH_LIBS_DIR="${BASE_BASH_LIBS_DIR:-$project_root/../../../lib/bash}"
}

run_app() { "$launcher" "$project_root/bin/app" "$@"; }

@test "operations CLI exposes status and completion workflows" {
    run run_app status
    [ "$status" -eq 0 ]
    [[ "$output" == *"workspace="* ]]
    run run_app completion
    [ "$status" -eq 0 ]
    [[ "$output" == *"ops_completion()"* ]]
}

@test "operations sync is safe in dry-run mode" {
    run run_app sync --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"dry-run=sync"* ]]
}

@test "operations diagnostics use optional command probes" {
    run run_app diagnose
    [ "$status" -eq 0 ]
    [[ "$output" == *"git="* ]]
}
