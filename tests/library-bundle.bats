#!/usr/bin/env bats

load ../lib/bash/tests/test_helper.sh

setup() {
    setup_test_tmpdir
}

@test "library bundle check enforces the single-file boundary" {
    bats_run "$BASE_REPO_ROOT/scripts/library-bundle" check
    [ "$status" -eq 0 ]
    [[ "$output" == *"one canonical file per public library"* ]]
}

@test "library bundle output is deterministic and verifiable" {
    local first="$TEST_TMPDIR/first" second="$TEST_TMPDIR/second"
    bats_run "$BASE_REPO_ROOT/scripts/library-bundle" bundle "$first"
    [ "$status" -eq 0 ]
    bats_run "$BASE_REPO_ROOT/scripts/library-bundle" bundle "$second"
    [ "$status" -eq 0 ]
    bats_run "$BASE_REPO_ROOT/scripts/library-bundle" verify "$first"
    [ "$status" -eq 0 ]
    bats_run "$BASE_REPO_ROOT/scripts/library-bundle" verify "$second"
    [ "$status" -eq 0 ]
    diff -ru "$first" "$second"
}

@test "library bundle rejects tampering and divergent overwrite" {
    local bundle="$TEST_TMPDIR/bundle"
    "$BASE_REPO_ROOT/scripts/library-bundle" bundle "$bundle"
    printf 'tampered\n' >> "$bundle/VERSION"
    bats_run "$BASE_REPO_ROOT/scripts/library-bundle" verify "$bundle"
    [ "$status" -eq 1 ]
    [[ "$output" == *"hash mismatch"* ]]
    bats_run "$BASE_REPO_ROOT/scripts/library-bundle" bundle "$bundle"
    [ "$status" -eq 2 ]
    [[ "$output" == *"refusing to overwrite"* ]]
}
