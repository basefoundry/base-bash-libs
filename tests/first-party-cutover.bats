#!/usr/bin/env bats

setup() {
    repo_root="$(cd "${BATS_TEST_DIRNAME}/.." && pwd -P)"
}

@test "cutover check accepts the published GA asset" {
    run "$repo_root/scripts/first-party-cutover" check
    [ "$status" -eq 0 ]
    [[ "$output" == *"structurally valid"* ]]
    run "$repo_root/scripts/first-party-cutover" check --allow-pending
    [ "$status" -eq 0 ]
    [[ "$output" == *"structurally valid"* ]]
}

@test "cutover check detects legacy Base symbols" {
    fixture="$BATS_TEST_TMPDIR/base"
    mkdir -p "$fixture"
    printf '%s\n' 'base_require_version 2.0.0' 'base_bash_libs_require_version 1.4.0' > "$fixture/base_init.sh"
    run "$repo_root/scripts/first-party-cutover" check --allow-pending --base-dir "$fixture"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Legacy base-bash-libs symbols"* ]]
}
