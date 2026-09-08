#!/usr/bin/env bats

load ../lib/bash/tests/test_helper.sh

setup() {
    setup_test_tmpdir
}

@test "release invariants use the published GA reference on mainline" {
    run env -u BASE_HOME BASE_CACHE_DIR="$TEST_TMPDIR/cache" \
        "$BASE_REPO_ROOT/tests/release-invariants.sh"
    [ "$status" -eq 0 ]
    candidate_version="$(<"$BASE_REPO_ROOT/VERSION")"
    if [[ "$candidate_version" == 2.0.0 ]]; then
        [[ "$output" == *"candidate_version=2.0.0 release_ref=v2.0.0"* ]]
        [[ "$output" == *"provenance=published GA tag from first-party-cutover.yaml"* ]]
    else
        [[ "$output" == *"candidate_version=$candidate_version release_ref=HEAD"* ]]
        [[ "$output" == *"provenance=candidate checkout (VERSION $candidate_version differs from v2.0.0)"* ]]
    fi
}

@test "release invariants use the candidate checkout when VERSION advances" {
    candidate_repo="$TEST_TMPDIR/candidate-repo"
    git clone --local "$BASE_REPO_ROOT" "$candidate_repo" > /dev/null
    printf '2.1.0\n' > "$candidate_repo/VERSION"

    run env -u BASE_HOME BASE_CACHE_DIR="$TEST_TMPDIR/candidate-cache" \
        "$candidate_repo/tests/release-invariants.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"candidate_version=2.1.0 release_ref=HEAD"* ]]
    [[ "$output" == *"provenance=candidate checkout (VERSION 2.1.0 differs from v2.0.0)"* ]]
}
