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

@test "library bundle verification binds the complete inventory and metadata" {
    local source="$TEST_TMPDIR/source" candidate first_line
    "$BASE_REPO_ROOT/scripts/library-bundle" bundle "$source" >/dev/null
    first_line="$(sed -n '1p' "$source/MANIFEST.sha256")"

    cp -R "$source" "$TEST_TMPDIR/omitted"
    tail -n +2 "$TEST_TMPDIR/omitted/MANIFEST.sha256" > "$TEST_TMPDIR/omitted/MANIFEST.tmp"
    mv "$TEST_TMPDIR/omitted/MANIFEST.tmp" "$TEST_TMPDIR/omitted/MANIFEST.sha256"
    bats_run "$BASE_REPO_ROOT/scripts/library-bundle" verify "$TEST_TMPDIR/omitted"
    [ "$status" -eq 1 ]
    [[ "$output" == *"omits expected file"* ]]

    cp -R "$source" "$TEST_TMPDIR/traversal"
    printf '%s  ../VERSION\n' "${first_line%%  *}" > "$TEST_TMPDIR/traversal/MANIFEST.sha256"
    bats_run "$BASE_REPO_ROOT/scripts/library-bundle" verify "$TEST_TMPDIR/traversal"
    [ "$status" -eq 1 ]
    [[ "$output" == *"unsafe checksum path"* ]]

    cp -R "$source" "$TEST_TMPDIR/duplicate"
    printf '%s\n' "$first_line" >> "$TEST_TMPDIR/duplicate/MANIFEST.sha256"
    bats_run "$BASE_REPO_ROOT/scripts/library-bundle" verify "$TEST_TMPDIR/duplicate"
    [ "$status" -eq 1 ]
    [[ "$output" == *"duplicate checksum entry"* ]]

    cp -R "$source" "$TEST_TMPDIR/extra"
    printf 'unexpected\n' > "$TEST_TMPDIR/extra/EXTRA"
    bats_run "$BASE_REPO_ROOT/scripts/library-bundle" verify "$TEST_TMPDIR/extra"
    [ "$status" -eq 1 ]
    [[ "$output" == *"unexpected file"* ]]

    cp -R "$source" "$TEST_TMPDIR/symlink"
    ln -s VERSION "$TEST_TMPDIR/symlink/SYMLINK"
    bats_run "$BASE_REPO_ROOT/scripts/library-bundle" verify "$TEST_TMPDIR/symlink"
    [ "$status" -eq 1 ]
    [[ "$output" == *"symlink"* ]]

    cp -R "$source" "$TEST_TMPDIR/metadata"
    awk '{ if ($0 ~ /^source_version=/) print "source_version=9.9.9"; else print }' \
        "$TEST_TMPDIR/metadata/BUNDLE.release" > "$TEST_TMPDIR/metadata/BUNDLE.tmp"
    mv "$TEST_TMPDIR/metadata/BUNDLE.tmp" "$TEST_TMPDIR/metadata/BUNDLE.release"
    bats_run "$BASE_REPO_ROOT/scripts/library-bundle" verify "$TEST_TMPDIR/metadata"
    [ "$status" -eq 1 ]
    [[ "$output" == *"hash mismatch: BUNDLE.release"* ]]
}
