#!/usr/bin/env bats

load ../lib/bash/tests/test_helper.sh

setup() {
    setup_test_tmpdir
    RELEASE_ARTIFACT="$BASE_REPO_ROOT/scripts/release-artifact"
    RELEASE_COMMIT="$(git -C "$BASE_REPO_ROOT" rev-parse HEAD)"
}

@test "release artifact build creates a deterministic verified asset set" {
    local first="$TEST_TMPDIR/first" second="$TEST_TMPDIR/second"

    bats_run "$RELEASE_ARTIFACT" build --version 2.0.0-rc.1 --commit "$RELEASE_COMMIT" --output "$first"
    [ "$status" -eq 0 ]
    bats_run "$RELEASE_ARTIFACT" verify "$first"
    [ "$status" -eq 0 ]
    [[ "$output" == *"verified"* ]]

    bats_run "$RELEASE_ARTIFACT" build --version 2.0.0-rc.1 --commit "$RELEASE_COMMIT" --output "$second"
    [ "$status" -eq 0 ]
    diff -ru "$first" "$second"
    grep -F '"spdxVersion": "SPDX-2.3"' "$first"/*.spdx.json
    grep -F '"reproducible": true' "$first"/*.provenance.json
}

@test "release artifact verification rejects a tampered asset" {
    local output="$TEST_TMPDIR/artifact"

    "$RELEASE_ARTIFACT" build --version 2.0.0-rc.1 --commit "$RELEASE_COMMIT" --output "$output"
    printf 'tampered\n' >> "$output"/*.tar.gz
    bats_run "$RELEASE_ARTIFACT" verify "$output"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Checksum mismatch"* ]]
}
