#!/usr/bin/env bats

load ../lib/bash/tests/test_helper.sh

setup() {
    setup_test_tmpdir
}

@test "release invariants compare the candidate tree with the published GA baseline" {
    run env -u BASE_HOME BASE_CACHE_DIR="$TEST_TMPDIR/cache" \
        "$BASE_REPO_ROOT/tests/release-invariants.sh"
    [ "$status" -eq 0 ]
    candidate_version="$(<"$BASE_REPO_ROOT/VERSION")"
    [[ "$output" == *"candidate_version=$candidate_version candidate_ref=HEAD compatibility_ref=v2.0.0"* ]]
    [[ "$output" == *"provenance=published GA tag from first-party-cutover.yaml"* ]]
}

@test "release invariants keep the published GA baseline when VERSION advances" {
    candidate_repo="$TEST_TMPDIR/candidate-repo"
    git clone --local "$BASE_REPO_ROOT" "$candidate_repo" > /dev/null
    printf '2.1.0\n' > "$candidate_repo/VERSION"

    run env -u BASE_HOME BASE_CACHE_DIR="$TEST_TMPDIR/candidate-cache" \
        "$candidate_repo/tests/release-invariants.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"candidate_version=2.1.0 candidate_ref=HEAD compatibility_ref=v2.0.0"* ]]
    [[ "$output" == *"provenance=published GA tag from first-party-cutover.yaml"* ]]
}

@test "release invariants reject a committed stable downgrade against the published baseline" {
    candidate_repo="$TEST_TMPDIR/downgraded-candidate"
    git clone --local "$BASE_REPO_ROOT" "$candidate_repo" > /dev/null
    perl -0pi -e 's/(  - name: gh\n.*?    stability: )stable/$1preview/s; s/(  - name: gh\n.*?    since: )2[.]0[.]0/$1unreleased/s' \
        "$candidate_repo/base_api_manifest.yaml"
    "$candidate_repo/scripts/api-manifest" generate base_api_manifest.yaml docs/api-reference.md
    git -C "$candidate_repo" add VERSION base_api_manifest.yaml docs/api-reference.md
    git -C "$candidate_repo" commit -m "test: downgrade stable API fixture" > /dev/null

    run env -u BASE_HOME BASE_CACHE_DIR="$TEST_TMPDIR/downgraded-cache" \
        "$candidate_repo/tests/release-invariants.sh"

    [ "$status" -ne 0 ]
    [[ "$output" == *"compatibility_ref=v2.0.0"* ]]
    [[ "$output" == *"stable module 'gh' was downgraded"* ]]
}

@test "release invariants accept an additive candidate against the published baseline" {
    candidate_repo="$TEST_TMPDIR/additive-candidate"
    git clone --local "$BASE_REPO_ROOT" "$candidate_repo" > /dev/null
    printf '2.1.0\n' > "$candidate_repo/VERSION"
    git -C "$candidate_repo" add VERSION
    git -C "$candidate_repo" commit -m "test: advance candidate version" > /dev/null

    run env -u BASE_HOME BASE_CACHE_DIR="$TEST_TMPDIR/additive-cache" \
        "$candidate_repo/tests/release-invariants.sh"

    [ "$status" -eq 0 ]
    [[ "$output" == *"candidate_version=2.1.0 candidate_ref=HEAD compatibility_ref=v2.0.0"* ]]
}
