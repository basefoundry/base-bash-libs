#!/usr/bin/env bats

setup() {
    project_root="$(cd -- "${BATS_TEST_DIRNAME}/.." && pwd -P)"
    launcher="${BASE_BASH_LAUNCHER:-$project_root/../../../bin/base-bash}"
    export BASE_BASH_LIBS_DIR="${BASE_BASH_LIBS_DIR:-$project_root/../../../lib/bash}"
}

run_app() { "$launcher" "$project_root/bin/app" "$@"; }

@test "release helper separates a non-mutating plan" {
    run run_app plan
    [ "$status" -eq 0 ]
    [[ "$output" == *"mutation=disabled"* ]]
}

@test "release helper requires an artifact before publishing" {
    run run_app publish
    [ "$status" -eq 2 ]
}

@test "release helper prints an explicit rollback target" {
    run run_app rollback
    [ "$status" -eq 0 ]
    [[ "$output" == *"immutable-release"* ]]
}
