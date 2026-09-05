#!/usr/bin/env bats

load ../lib/bash/tests/test_helper.sh

setup() {
    setup_test_tmpdir
    RELEASE_ARTIFACT="$BASE_REPO_ROOT/scripts/release-artifact"
    RELEASE_COMMIT="$(git -C "$BASE_REPO_ROOT" rev-parse HEAD)"
}

release_test_hash_file() {
    if command -v sha256sum > /dev/null 2>&1; then
        sha256sum -- "$1" | awk '{print $1}'
    else
        shasum -a 256 -- "$1" | awk '{print $1}'
    fi
}

release_test_refresh_checksum() {
    local asset="$1" sums="$2" name hash temporary
    name="${asset##*/}"
    hash="$(release_test_hash_file "$asset")"
    temporary="$TEST_TMPDIR/checksums.tmp"
    awk -v name="$name" -v hash="$hash" '
        $2 == name { $1 = hash }
        { printf "%s  %s\n", $1, $2 }
    ' "$sums" > "$temporary"
    mv -- "$temporary" "$sums"
}

release_test_build() {
    local destination="$1" version="${2:-2.0.0-rc.1}"
    "$RELEASE_ARTIFACT" build --version "$version" --commit "$RELEASE_COMMIT" --output "$destination" > /dev/null
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

@test "release artifact build rejects duplicate options" {
    local output="$TEST_TMPDIR/duplicate"
    bats_run "$RELEASE_ARTIFACT" build \
        --version 2.0.0-rc.1 --version 2.0.0-rc.1 \
        --commit "$RELEASE_COMMIT" --output "$output"
    [ "$status" -eq 2 ]
    [[ "$output" == *"Option '--version' may be provided only once."* ]]

    bats_run "$RELEASE_ARTIFACT" build \
        --version 2.0.0-rc.1 --commit "$RELEASE_COMMIT" \
        --output "$output" --output "$output"
    [ "$status" -eq 2 ]
    [[ "$output" == *"Option '--output' may be provided only once."* ]]

    bats_run "$RELEASE_ARTIFACT" build \
        --version 2.0.0-rc.1 --commit "$RELEASE_COMMIT" \
        --commit "$RELEASE_COMMIT" --output "$output"
    [ "$status" -eq 2 ]
    [[ "$output" == *"Option '--commit' may be provided only once."* ]]
}

@test "release artifact build and verify support post-GA patch and minor versions" {
    local version artifact

    for version in 2.0.1 2.1.0; do
        artifact="$TEST_TMPDIR/artifact-$version"
        release_test_build "$artifact" "$version"
        bats_run "$RELEASE_ARTIFACT" verify "$artifact"
        [ "$status" -eq 0 ]
        [[ "$output" == *"verified"* ]]
        [ -f "$artifact/base-bash-libs-v$version.tar.gz" ]
        [ -f "$artifact/base-bash-libs-v$version.spdx.json" ]
        [ -f "$artifact/base-bash-libs-v$version.provenance.json" ]
        [ -f "$artifact/base-bash-libs-v$version.SHA256SUMS" ]
    done
}

@test "release artifact verification rejects a tampered asset" {
    local output="$TEST_TMPDIR/artifact"

    "$RELEASE_ARTIFACT" build --version 2.0.0-rc.1 --commit "$RELEASE_COMMIT" --output "$output"
    printf 'tampered\n' >> "$output"/*.tar.gz
    bats_run "$RELEASE_ARTIFACT" verify "$output"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Checksum mismatch"* ]]
}

@test "release artifact verification requires checksum coverage for every mandatory asset" {
    local artifact="$TEST_TMPDIR/artifact" sums provenance temporary

    release_test_build "$artifact"
    sums="$artifact/base-bash-libs-v2.0.0-rc.1.SHA256SUMS"
    provenance="base-bash-libs-v2.0.0-rc.1.provenance.json"
    temporary="$TEST_TMPDIR/checksums.tmp"
    awk -v name="$provenance" '$2 != name { printf "%s  %s\n", $1, $2 }' "$sums" > "$temporary"
    mv -- "$temporary" "$sums"

    bats_run "$RELEASE_ARTIFACT" verify "$artifact"
    [ "$status" -eq 1 ]
    [[ "$output" == *"does not cover mandatory asset"* ]]
}

@test "release artifact verification rejects duplicate and unsafe checksum records" {
    local artifact="$TEST_TMPDIR/artifact" sums first_line temporary

    release_test_build "$artifact"
    sums="$artifact/base-bash-libs-v2.0.0-rc.1.SHA256SUMS"
    first_line="$(sed -n '1p' "$sums")"
    printf '%s\n' "$first_line" >> "$sums"
    bats_run "$RELEASE_ARTIFACT" verify "$artifact"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Duplicate checksum entry"* ]]

    release_test_build "$TEST_TMPDIR/unsafe"
    sums="$TEST_TMPDIR/unsafe/base-bash-libs-v2.0.0-rc.1.SHA256SUMS"
    temporary="$TEST_TMPDIR/checksums.tmp"
    awk 'NR == 1 { $2 = "../" $2 } { printf "%s  %s\n", $1, $2 }' "$sums" > "$temporary"
    mv -- "$temporary" "$sums"
    bats_run "$RELEASE_ARTIFACT" verify "$TEST_TMPDIR/unsafe"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Malformed checksum entry"* || "$output" == *"unsafe checksum entry"* ]]
}

@test "release artifact verification binds provenance to the archive and embedded commit" {
    local artifact="$TEST_TMPDIR/artifact" provenance sums temporary

    release_test_build "$artifact"
    provenance="$artifact/base-bash-libs-v2.0.0-rc.1.provenance.json"
    sums="$artifact/base-bash-libs-v2.0.0-rc.1.SHA256SUMS"
    temporary="$TEST_TMPDIR/provenance.tmp"
    sed 's/"sourceCommit": "[[:xdigit:]]\{40\}"/"sourceCommit": "0000000000000000000000000000000000000000"/' \
        "$provenance" > "$temporary"
    mv -- "$temporary" "$provenance"
    release_test_refresh_checksum "$provenance" "$sums"

    bats_run "$RELEASE_ARTIFACT" verify "$artifact"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Provenance version and source commit disagree"* ]]

    release_test_build "$TEST_TMPDIR/subject"
    provenance="$TEST_TMPDIR/subject/base-bash-libs-v2.0.0-rc.1.provenance.json"
    sums="$TEST_TMPDIR/subject/base-bash-libs-v2.0.0-rc.1.SHA256SUMS"
    temporary="$TEST_TMPDIR/provenance.tmp"
    sed 's/"sha256": "[[:xdigit:]]\{64\}"/"sha256": "0000000000000000000000000000000000000000000000000000000000000000"/' \
        "$provenance" > "$temporary"
    mv -- "$temporary" "$provenance"
    release_test_refresh_checksum "$provenance" "$sums"
    bats_run "$RELEASE_ARTIFACT" verify "$TEST_TMPDIR/subject"
    [ "$status" -eq 1 ]
    [[ "$output" == *"subject does not bind"* ]]
}

@test "release artifact verification binds the SBOM to version and commit identity" {
    local artifact="$TEST_TMPDIR/artifact" sbom sums temporary

    release_test_build "$artifact"
    sbom="$artifact/base-bash-libs-v2.0.0-rc.1.spdx.json"
    sums="$artifact/base-bash-libs-v2.0.0-rc.1.SHA256SUMS"
    temporary="$TEST_TMPDIR/sbom.tmp"
    sed 's#/releases/v2.0.0-rc.1/[[:xdigit:]]\{40\}"#/releases/v2.0.0-rc.1/0000000000000000000000000000000000000000"#' \
        "$sbom" > "$temporary"
    mv -- "$temporary" "$sbom"
    release_test_refresh_checksum "$sbom" "$sums"

    bats_run "$RELEASE_ARTIFACT" verify "$artifact"
    [ "$status" -eq 1 ]
    [[ "$output" == *"SBOM namespace disagrees"* ]]
}

@test "release artifact verification rejects mismatched versions and ambiguous assets" {
    local artifact="$TEST_TMPDIR/artifact"

    release_test_build "$artifact"
    mv -- "$artifact/base-bash-libs-v2.0.0-rc.1.spdx.json" \
        "$artifact/base-bash-libs-v2.0.0.spdx.json"
    bats_run "$RELEASE_ARTIFACT" verify "$artifact"
    [ "$status" -eq 1 ]
    [[ "$output" == *"filenames do not identify the same version"* ]]

    release_test_build "$TEST_TMPDIR/ambiguous"
    cp -- "$TEST_TMPDIR/ambiguous/base-bash-libs-v2.0.0-rc.1.tar.gz" \
        "$TEST_TMPDIR/ambiguous/base-bash-libs-v2.0.0.tar.gz"
    bats_run "$RELEASE_ARTIFACT" verify "$TEST_TMPDIR/ambiguous"
    [ "$status" -eq 1 ]
    [[ "$output" == *"exactly one archive"* ]]
}
