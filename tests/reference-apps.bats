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

@test "reference applications rehearse candidate and rollback boundaries" {
    run "$repo_root/examples/reference-apps/release-rehearsal.sh" \
        --candidate "$repo_root" \
        --rollback "$repo_root" \
        --report "$BATS_TEST_TMPDIR/reference-release.tsv"

    [ "$status" -eq 0 ]
    [[ "$output" == *"candidate and rollback apps=3"* ]]
    grep -F $'phase=candidate\tapp=installer\tstatus=pass' "$BATS_TEST_TMPDIR/reference-release.tsv"
    grep -F $'phase=rollback\tapp=ops-cli\tstatus=pass' "$BATS_TEST_TMPDIR/reference-release.tsv"
}
