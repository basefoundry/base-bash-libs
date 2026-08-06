#!/usr/bin/env bats

setup() {
    repo_root="$(cd "${BATS_TEST_DIRNAME}/.." && pwd -P)"
    export BASE_BASH_LIBS_DIR="$repo_root/lib/bash"
    export BASE_BASH_LAUNCHER="$repo_root/bin/base-bash"
}

@test "reference application package passes launcher smoke" {
    run "$repo_root/examples/reference-apps/verify.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"passed launcher smoke checks"* ]]
}

@test "reference application failure suites remain green" {
    for app in installer release-helper ops-cli; do
        run bats "$repo_root/examples/reference-apps/$app/tests/app.bats"
        [ "$status" -eq 0 ]
    done
}
